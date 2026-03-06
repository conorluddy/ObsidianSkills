
<img alt="Screenshot 2026-03-05 at 07 05 29" src="https://github.com/user-attachments/assets/e1e88c1a-3b51-4235-b01e-567d924dd42e" />

# ObsidianSkills

A collection of [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skills for integrating your Obsidian vault with development workflows. Symlinks, not copies — source files stay where they belong.

## Skills

| Skill | Purpose |
|-------|---------|
| [obsidian-link](#obsidian-link) | Bridge Claude Code config (agents, skills, plans) into your vault |
| [obsidian-github-issue-fetcher](#obsidian-github-issue-fetcher) | Fetch GitHub issues into your vault as browsable markdown notes |

---

## obsidian-link

Connect Claude Code's dotfile configuration to your Obsidian vault via symlinks, making agents, skills, and plans visible in graph view and Dataview queries.

### Modes

| Mode | Command | Purpose |
|------|---------|---------|
| **Link** | `/obsidian-link` | Connect current project's agents/skills to vault |
| **Status** | `/obsidian-link status` | Health check across all linked projects |
| **Unlink** | `/obsidian-link unlink <project>` | Remove a project's links from vault |
| **Init** | `/obsidian-link init` | Configure plan frontmatter in `~/.claude/CLAUDE.md` |

### Vault structure

```
<vault>/ClaudeCode/
  ├── README.md           # Auto-generated index with [[wikilinks]]
  ├── Agents/
  │   ├── global/         # Authored here, symlinked into ~/.claude/
  │   └── <project>/      # Symlinks back to repo .claude/agents/
  ├── Skills/
  │   ├── global/         # Authored here, symlinked into ~/.claude/
  │   └── <project>/      # Symlinks back to repo .claude/skills/
  └── Plans/              # ~/.claude/plans symlinks here
```

### Symlink direction

| Config type | Source of truth | Symlinked into |
|-------------|----------------|----------------|
| Per-project agents/skills | Project repo (`.claude/`) | Obsidian vault |
| Global agents/skills | Obsidian vault | `~/.claude/` |
| Plans | Obsidian vault | `~/.claude/plans` |

### Safety

- Never auto-deletes broken symlinks (reports only)
- Never overwrites existing non-symlink configs
- Idempotent — safe to re-run
- Unlink only removes symlinks, never source files

---

## obsidian-github-issue-fetcher

One-way fetch (GitHub → Obsidian) that turns issues into vault-native markdown notes with full frontmatter for Dataview queries, tags, and graph view.

### Modes

| Mode | Command | Purpose |
|------|---------|---------|
| **Fetch** | `/obsidian-github-issue-fetcher` | Fetch all issues from current repo |
| **Status** | `/obsidian-github-issue-fetcher status` | Show last fetch info |
| **Init** | `/obsidian-github-issue-fetcher init` | Configure vault path |
| **Dry run** | `/obsidian-github-issue-fetcher --dry-run` | Preview without writing |
| **Force** | `/obsidian-github-issue-fetcher --force` | Re-fetch all, skip unchanged check |

### Output structure

```
<vault>/GithubIssues/<project>/
  ├── .sync-state.json
  ├── 1-add-user-auth.md
  ├── 2-fix-login-bug.md
  └── 3-update-deps.md
```

### Frontmatter

Each issue note includes full YAML frontmatter:

```yaml
---
type: issue
id: issue-myapp-42
title: "Add OAuth support"
status: open
issue_number: 42
repo: yourname/myapp
url: https://github.com/yourname/myapp/issues/42
author: yourname
labels:
  - enhancement
  - auth
assignees:
  - yourname
milestone: "v2.0"
projects:
  - proj-myapp
tags:
  - issue
  - myapp
created: "2026-03-01"
updated: "2026-03-04"
---
```

### Dataview example

```dataview
TABLE status, author, updated
FROM "GithubIssues"
WHERE status = "open"
SORT updated DESC
```

### Notes

- Closed issues are updated in-place, never deleted
- User content below `<!-- gh-sync-end -->` is preserved across re-syncs
- Unchanged files are skipped (no timestamp churn) unless `--force` is used
- Run from different repos to sync different projects

---

## Install

```bash
# Clone
git clone https://github.com/yourname/ObsidianSkills.git

# Symlink whichever skills you want into Claude Code
ln -sf "$(pwd)/ObsidianSkills/obsidian-link" ~/.claude/skills/obsidian-link
ln -sf "$(pwd)/ObsidianSkills/obsidian-github-issue-fetcher" ~/.claude/skills/obsidian-github-issue-fetcher
```

## Configuration

Both skills resolve the vault path the same way:

1. `OBSIDIAN_VAULT` environment variable
2. `~/.obsidian-vault` file containing the absolute path

Run either skill's `init` mode to configure the path interactively.

## Prerequisites

- `gh` CLI installed and authenticated
- `jq` installed (`brew install jq`)
- An Obsidian vault

## License

MIT
