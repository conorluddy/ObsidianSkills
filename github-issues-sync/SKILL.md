---
name: github-issues-sync
description: "Sync GitHub issues into Obsidian as markdown notes — turn your vault into an issue tracker with Dataview queries, tags, and graph view. Sync issues as notes, GitHub issues in Obsidian, issue tracker in vault, Dataview issues dashboard. Four modes: `/github-issues-sync` (sync, default), `/github-issues-sync status` (last sync info), `/github-issues-sync init` (configure vault path), `/github-issues-sync --dry-run` (preview without writing). Also supports `--force` to re-sync all issues regardless of changes."
---

# github-issues-sync

Sync GitHub issues from the current repo into the Obsidian vault as browsable, cross-referenceable markdown notes.

**Direction**: One-way (GitHub → Obsidian). Issues become vault citizens with frontmatter for Dataview queries, tags, and graph view.

## Mode Dispatch

Parse the user's input to determine mode:
- `/github-issues-sync` → **Sync mode** (default)
- `/github-issues-sync status` → **Status mode**
- `/github-issues-sync init` → **Init mode** (configure vault path)
- `/github-issues-sync --dry-run` → **Dry run mode**

## Execution

Determine the skill directory path (where this SKILL.md lives), then run the sync script from the **user's current working directory** (so `gh` auto-detects the correct repo):

```bash
bash <skill-dir>/sync.sh              # Default: sync issues
bash <skill-dir>/sync.sh --init       # First-time vault setup
bash <skill-dir>/sync.sh --status     # Show last sync state
bash <skill-dir>/sync.sh --dry-run    # Preview without writing
bash <skill-dir>/sync.sh --force      # Re-sync all, skip unchanged check
```

## Prerequisites

- `gh` CLI installed and authenticated (`gh auth status`)
- `jq` installed (`brew install jq`)
- Current directory is inside a GitHub repository
- Vault path configured via `~/.obsidian-vault` or `OBSIDIAN_VAULT` env var

## Output

Issues are written to `<vault>/GithubIssues/<Project>/` with:
- Frontmatter: type, id, title, status, labels, assignees, milestone, repo URL
- Body: issue markdown content
- User content below `<!-- gh-sync-end -->` marker is preserved across re-syncs

## Notes

- Auto-detects repo from current directory via `gh repo view`
- Closed issues are updated in-place (status changes), never deleted
- Unchanged files are skipped (no timestamp churn)
- Run from different repos to sync different projects
