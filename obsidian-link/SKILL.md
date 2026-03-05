---
name: obsidian-link
description: "Link, inspect, or unlink a project's Claude Code agents and skills in an Obsidian vault. Three modes: `/obsidian-link` (link, default), `/obsidian-link status` (health check), `/obsidian-link unlink <project>` (remove). Handles idempotency, broken symlink detection, Plans symlink, and auto-generates an Obsidian index note with wikilinks."
---

# obsidian-link

Connect a project's Claude Code configuration (agents, skills) to an Obsidian vault for browsing, searching, and cross-referencing.

**Directionality**:
- **Global agents/skills**: Obsidian is source of truth, symlinked into `~/.claude/`
- **Per-project agents/skills**: Project repo is source of truth, symlinked into Obsidian

## Mode Dispatch

Parse the user's input to determine mode:
- `/obsidian-link` or `/obsidian-link link` → **Link mode** (default)
- `/obsidian-link status` → **Status mode**
- `/obsidian-link unlink <project>` → **Unlink mode**

## Configuration

### Resolving the vault path

Check in order:
1. `OBSIDIAN_VAULT` environment variable
2. `~/.obsidian-vault` file (single line, absolute path)

If found, **confirm with the user**. If not found, ask. Once confirmed, offer to save to `~/.obsidian-vault`.

### Directory structure

```
<vault>/ClaudeCode/
  ├── README.md           # Auto-generated index (wikilinks)
  ├── Agents/
  │   ├── global/
  │   └── <project>/
  ├── Skills/
  │   ├── global/
  │   └── <project>/
  └── Plans/              # ~/.claude/plans → here
```

---

## Link Mode (default)

### Step 1: Resolve vault + ensure directories

Confirm vault path, then: `mkdir -p "<vault>/ClaudeCode/{Agents/global,Skills/global,Plans}"`

### Step 2: Plans symlink

Check `~/.claude/plans`:
- Missing → `ln -sf "<vault>/ClaudeCode/Plans" "$HOME/.claude/plans"`
- Exists, target matches vault → skip (OK)
- Exists, points elsewhere → warn and skip (do not overwrite)

### Step 3: Detect project

`git rev-parse --show-toplevel` → basename, lowercased. If not in a git repo, ask for project name and root path.

### Step 4: Link project agents (idempotent)

If `<repo>/.claude/agents/` exists, `mkdir -p "<vault>/ClaudeCode/Agents/<project>"`.

For each `.md` file, before creating a symlink, check existing state:
```bash
target="<vault>/ClaudeCode/Agents/<project>/<file>"
expected="<repo>/.claude/agents/<file>"
current=$(readlink "$target" 2>/dev/null)

if [ "$current" = "$expected" ]; then
  # already_linked — skip
elif [ -L "$target" ]; then
  # wrong target — overwrite (count as updated)
  ln -sf "$expected" "$target"
else
  # new — create
  ln -sf "$expected" "$target"
fi
```

Track counts: `new`, `already_linked`, `updated`.

### Step 5: Link project skills (idempotent)

Same pattern as Step 4, but for each skill directory in `<repo>/.claude/skills/`.

### Step 6: Sync global skills into ~/.claude

For each skill directory in `<vault>/ClaudeCode/Skills/global/` (must contain `SKILL.md`):
- If `~/.claude/skills/<name>` doesn't exist → create symlink
- If it exists and points to vault → skip
- If it exists and points elsewhere → skip (never overwrite non-Obsidian skills)

### Step 7: Sync global agents into ~/.claude

- `~/.claude/agents` doesn't exist → `ln -sf "<vault>/ClaudeCode/Agents/global" "$HOME/.claude/agents"`
- Exists as symlink to vault → skip
- Exists as real directory or wrong symlink → warn, skip

### Step 8: Broken symlink detection

After all linking:
```bash
find "<vault>/ClaudeCode/Agents" "<vault>/ClaudeCode/Skills" -type l ! -exec test -e {} \; -print
```

Report broken links with their targets. **Suggest cleanup but never auto-delete.**

### Step 9: Generate index note

Write `<vault>/ClaudeCode/README.md` (fully regenerated each run):

```markdown
---
type: index
title: Claude Code Hub
updated: <YYYY-MM-DD>
tags:
  - claude-code
  - index
---

# Claude Code Hub

## Projects

| Project | Agents | Skills | Status |
|---------|--------|--------|--------|
| <name> | <count> | <count> | OK / N broken |

## Global

| Type | Name | Link |
|------|------|------|
| Agent | <name> | [[<name>]] |
| Skill | <name> | [[<name>]] |

## Plans

<count> plan files in ClaudeCode/Plans/
```

Use `[[wikilinks]]` for all agent and skill names so Obsidian's graph view connects them. Scan `Agents/` and `Skills/` subdirs (excluding `global/`) for project names.

### Step 10: Report

```
obsidian-link: <project>

  Vault:   <vault-path>
  Project: <project> (<repo-root>)

  Agents: <N> new, <N> already linked
  Skills: <N> new, <N> already linked
  Broken: none | <N> broken (listed above)
  Plans:  ~/.claude/plans → vault (OK) | WARNING: points elsewhere | created

  Global: <N> skills synced, agents symlink OK
  Index:  ClaudeCode/README.md updated
```

---

## Status Mode

Scans the vault's `ClaudeCode/` directories (not the filesystem) to report health of all linked projects.

### Steps

1. Resolve vault path (same as Link mode Step 1)
2. Scan `<vault>/ClaudeCode/Agents/` and `Skills/` for project subdirs (excluding `global/`)
3. For each project: count symlinks, count broken symlinks, report health
4. Check global sync: agents symlink target, skills presence
5. Check Plans symlink
6. Regenerate index note (Step 9 from Link mode)

### Report format

```
obsidian-link status

  Vault: <vault-path>

  Projects:
    grapla     — 16 agents, 1 skill, 0 broken
    afterset   — 4 agents, 2 skills, 1 broken
      broken: afterset/old-agent.md → /path/that/moved

  Global: agents OK, 3 skills synced
  Plans:  ~/.claude/plans → vault (OK)
  Index:  ClaudeCode/README.md updated
```

---

## Unlink Mode

Removes a project's symlinks from the vault. **Never deletes repo files.**

### Steps

1. Resolve vault path
2. Validate `<project>` exists in `<vault>/ClaudeCode/Agents/<project>` or `Skills/<project>`
3. Show what will be removed (counts per directory)
4. **Ask for explicit user confirmation before proceeding**
5. Remove the project's directories:
   ```bash
   rm -rf "<vault>/ClaudeCode/Agents/<project>"
   rm -rf "<vault>/ClaudeCode/Skills/<project>"
   ```
   These dirs contain only symlinks — repo source files are untouched.
6. Regenerate index note

### Report format

```
obsidian-link unlink: <project>

  Removed: 16 agent links, 1 skill link
  Source files in <repo-root> are untouched.
  Index: ClaudeCode/README.md updated
```

---

## Notes

- **Never auto-delete broken symlinks** — report them and let the user decide
- **Never overwrite non-Obsidian configs** — if `~/.claude/agents` is a real directory, warn and skip
- **Idempotent by design** — running Link mode repeatedly produces the same result with accurate counts
- **Index note is disposable** — fully regenerated each run, safe to delete manually
