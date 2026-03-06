#!/usr/bin/env bash
set -euo pipefail

# GitHub Issues → Obsidian Sync
# Syncs a repo's GitHub issues into the Obsidian vault as markdown notes.
# Dependencies: gh, jq

# === CONFIGURATION ===

VAULT_CONFIG="$HOME/.obsidian-vault"
SYNC_DIR_NAME="GithubIssues"
ISSUE_LIMIT=500

# === HELPERS ===

die() { echo "ERROR: $1" >&2; exit 1; }
info() { echo "$1"; }

resolve_vault() {
  if [[ -n "${OBSIDIAN_VAULT:-}" ]]; then
    VAULT="$OBSIDIAN_VAULT"
  elif [[ -f "$VAULT_CONFIG" ]]; then
    VAULT="$(head -1 "$VAULT_CONFIG")"
  elif [[ "$MODE" == "init" ]]; then
    echo "No vault configured. Enter your Obsidian vault path:"
    read -r VAULT
    [[ -d "$VAULT" ]] || die "Directory does not exist: $VAULT"
    echo "$VAULT" > "$VAULT_CONFIG"
    info "Saved vault path to $VAULT_CONFIG"
  else
    die "No vault configured. Run: $0 --init"
  fi
  [[ -d "$VAULT" ]] || die "Vault directory not found: $VAULT"
}

detect_repo() {
  command -v gh >/dev/null 2>&1 || die "'gh' CLI not found. Install: https://cli.github.com"
  command -v jq >/dev/null 2>&1 || die "'jq' not found. Install: brew install jq"

  REPO_SLUG=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null) \
    || die "Not in a GitHub repo, or 'gh' not authenticated."
  PROJECT=$(basename "$REPO_SLUG")
  PROJECT_TAG=$(echo "$PROJECT" | tr '[:upper:]' '[:lower:]')
}

kebab_title() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9 -]//g' \
    | sed 's/  */ /g' \
    | sed 's/ /-/g' \
    | cut -c1-50
}

# === MODES ===

do_status() {
  resolve_vault
  detect_repo
  local state_file="$VAULT/$SYNC_DIR_NAME/$PROJECT/.sync-state.json"
  if [[ -f "$state_file" ]]; then
    info "Last sync state for $PROJECT:"
    jq '.' "$state_file"
  else
    info "No sync state found for $PROJECT. Run sync first."
  fi
}

do_sync() {
  local force="${1:-false}"
  resolve_vault
  detect_repo

  local out_dir="$VAULT/$SYNC_DIR_NAME/$PROJECT"
  mkdir -p "$out_dir"

  info "Fetching issues from $REPO_SLUG..."
  local issues_json
  issues_json=$(gh issue list \
    --json number,title,body,labels,state,assignees,url,createdAt,updatedAt,milestone,author \
    --limit "$ISSUE_LIMIT" \
    --state all)

  local total
  total=$(echo "$issues_json" | jq 'length')
  info "Processing $total issues..."
  [[ "$force" == "true" ]] && info "(Force mode: re-syncing all files)"

  # Pre-extract all fields per issue in a single jq pass (tab-separated)
  local extracted
  extracted=$(echo "$issues_json" | jq -r '.[] | [
    .number,
    .title,
    (.state | ascii_downcase),
    .url,
    .createdAt[:10],
    .updatedAt[:10],
    (.author.login // ""),
    (.milestone.title // ""),
    ([.labels[].name] | if length == 0 then "[]" else map("  - " + .) | join("\n") end),
    ([.assignees[].login] | if length == 0 then "[]" else map("  - " + .) | join("\n") end),
    (.body // "")
  ] | @base64')

  # Use temp file for counters (pipe creates subshell, losing variable changes)
  local count_file
  count_file=$(mktemp)
  echo "0 0 0" > "$count_file"

  while IFS= read -r encoded; do
    local decoded
    decoded=$(echo "$encoded" | base64 --decode)

    local number title state url created_at updated_at author milestone_name labels_yaml assignees_yaml body

    number=$(echo "$decoded" | jq -r '.[0]')
    title=$(echo "$decoded" | jq -r '.[1]')
    state=$(echo "$decoded" | jq -r '.[2]')
    url=$(echo "$decoded" | jq -r '.[3]')
    created_at=$(echo "$decoded" | jq -r '.[4]')
    updated_at=$(echo "$decoded" | jq -r '.[5]')
    author=$(echo "$decoded" | jq -r '.[6]')
    milestone_name=$(echo "$decoded" | jq -r '.[7]')
    labels_yaml=$(echo "$decoded" | jq -r '.[8]')
    assignees_yaml=$(echo "$decoded" | jq -r '.[9]')
    body=$(echo "$decoded" | jq -r '.[10]')

    local slug filename
    slug=$(kebab_title "$title")
    filename="${number}-${slug}.md"

    # Build frontmatter
    local frontmatter
    frontmatter="---
type: issue
id: issue-${PROJECT_TAG}-${number}
title: \"$(echo "$title" | sed 's/"/\\"/g')\"
status: ${state}
issue_number: ${number}
repo: ${REPO_SLUG}
url: ${url}
author: ${author}"

    if [[ "$labels_yaml" == "[]" ]]; then
      frontmatter="${frontmatter}
labels: []"
    else
      frontmatter="${frontmatter}
labels:
${labels_yaml}"
    fi

    if [[ "$assignees_yaml" == "[]" ]]; then
      frontmatter="${frontmatter}
assignees: []"
    else
      frontmatter="${frontmatter}
assignees:
${assignees_yaml}"
    fi

    if [[ -n "$milestone_name" ]]; then
      frontmatter="${frontmatter}
milestone: \"$(echo "$milestone_name" | sed 's/"/\\"/g')\""
    fi

    frontmatter="${frontmatter}
projects:
  - proj-${PROJECT_TAG}
tags:
  - issue
  - ${PROJECT_TAG}
created: \"${created_at}\"
updated: \"${updated_at}\"
---"

    # Build full content
    local gh_content="${frontmatter}

# #${number}: ${title}

${body}

<!-- gh-sync-end -->"

    local filepath="$out_dir/$filename"

    if [[ -f "$filepath" ]]; then
      # Preserve user content below the marker
      local user_content=""
      if grep -q '<!-- gh-sync-end -->' "$filepath"; then
        user_content=$(sed -n '/<!-- gh-sync-end -->/,$ { /<!-- gh-sync-end -->/d; p; }' "$filepath")
      fi

      # Skip unchanged files unless --force
      if [[ "$force" != "true" ]]; then
        local existing_synced=""
        if grep -q '<!-- gh-sync-end -->' "$filepath"; then
          existing_synced=$(sed '/<!-- gh-sync-end -->/q' "$filepath")
        else
          existing_synced=$(cat "$filepath")
        fi

        if [[ "$existing_synced" == "$gh_content" ]]; then
          read -r n u uc < "$count_file"; echo "$n $u $((uc + 1))" > "$count_file"
          continue
        fi
      fi

      # Write updated content, preserving user notes
      if [[ -n "$user_content" ]]; then
        printf '%s\n%s' "$gh_content" "$user_content" > "$filepath"
      else
        echo "$gh_content" > "$filepath"
      fi
      read -r n u uc < "$count_file"; echo "$n $((u + 1)) $uc" > "$count_file"
    else
      echo "$gh_content" > "$filepath"
      read -r n u uc < "$count_file"; echo "$((n + 1)) $u $uc" > "$count_file"
    fi
  done <<< "$extracted"

  local new updated unchanged
  read -r new updated unchanged < "$count_file"
  rm -f "$count_file"

  # Write sync state
  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  jq -n \
    --arg ts "$now" \
    --arg repo "$REPO_SLUG" \
    --argjson count "$total" \
    '{ lastSyncedAt: $ts, repo: $repo, issueCount: $count }' \
    > "$out_dir/.sync-state.json"

  info ""
  info "Synced $total issues to $out_dir"
  info "  New: $new | Updated: $updated | Unchanged: $unchanged"
}

do_dry_run() {
  resolve_vault
  detect_repo

  local out_dir="$VAULT/$SYNC_DIR_NAME/$PROJECT"
  info "[DRY RUN] Would sync issues from $REPO_SLUG"
  info "[DRY RUN] Target: $out_dir/"

  local issues_json total
  issues_json=$(gh issue list \
    --json number,title,state \
    --limit "$ISSUE_LIMIT" \
    --state all)
  total=$(echo "$issues_json" | jq 'length')

  local existing=0
  [[ -d "$out_dir" ]] && existing=$(find "$out_dir" -name '*.md' -maxdepth 1 | wc -l | tr -d ' ')

  info "[DRY RUN] Found $total issues on GitHub"
  info "[DRY RUN] Existing files in vault: $existing"
  info "[DRY RUN] No files were written."
}

# === MAIN ===

MODE="sync"
FORCE="false"
case "${1:-}" in
  --init)    MODE="init" ;;
  --dry-run) MODE="dry-run" ;;
  --status)  MODE="status" ;;
  --force)   FORCE="true" ;;
  --help|-h) echo "Usage: $0 [--init|--dry-run|--status|--force|--help]"; exit 0 ;;
esac

case "$MODE" in
  init)    resolve_vault; info "Vault configured: $VAULT" ;;
  status)  do_status ;;
  dry-run) do_dry_run ;;
  sync)    do_sync "$FORCE" ;;
esac
