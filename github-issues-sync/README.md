# github-issues-sync

Sync GitHub issues into your Obsidian vault as markdown notes. One-way (GitHub → Obsidian), zero dependencies beyond `gh` and `jq`.

## Setup

```bash
# 1. Configure vault path (one-time)
./sync.sh --init

# 2. Sync issues from any repo
cd ~/Development/MyProject
bash ~/Development/ObsidianSkills/github-issues-sync/sync.sh
```

Or install as a Claude Code skill by symlinking into a project's `.claude/skills/`.

## Usage

```bash
./sync.sh              # Sync current repo's issues to vault
./sync.sh --init       # Configure vault path (~/.obsidian-vault)
./sync.sh --status     # Show last sync time and issue count
./sync.sh --dry-run    # Preview what would happen, write nothing
```

## How It Works

1. Auto-detects the GitHub repo via `gh repo view`
2. Fetches all issues (open + closed, up to 500)
3. Writes each as `<number>-<kebab-title>.md` into `<vault>/GithubIssues/<Project>/`
4. Generates frontmatter compatible with Obsidian Dataview and graph view
5. Preserves any notes you add below the `<!-- gh-sync-end -->` marker
6. Skips unchanged files to avoid timestamp churn

## Output Structure

```
ObsidianVault/
  GithubIssues/
    MyApp/
      1-initial-setup.md
      42-fix-login-bug.md
      .sync-state.json
    AnotherRepo/
      7-add-dark-mode.md
      ...
```

## Frontmatter

Each issue gets frontmatter for Obsidian queries:

```yaml
---
type: issue
id: issue-myapp-42
title: "Fix login bug"
status: open
issue_number: 42
repo: yourname/myapp
url: https://github.com/yourname/myapp/issues/42
labels:
  - bug
  - v1
assignees:
  - yourname
milestone: "v1 Launch"
projects:
  - proj-myapp
tags:
  - issue
  - myapp
created: "2026-01-15"
updated: "2026-03-05"
---
```

## Dataview Examples

```dataview
TABLE status, labels, milestone
FROM "GithubIssues/MyApp"
WHERE status = "open"
SORT issue_number DESC
```

## Requirements

- [gh CLI](https://cli.github.com) — authenticated (`gh auth status`)
- [jq](https://jqlang.github.io/jq/) — `brew install jq`
