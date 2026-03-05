---
name: obsidian-link
description: "Link, inspect, or unlink a project's Claude Code agents and skills in an Obsidian vault. Four modes: `/obsidian-link` (link, default), `/obsidian-link status` (health check), `/obsidian-link unlink <project>` (remove), `/obsidian-link init` (configure plan frontmatter in CLAUDE.md). Handles idempotency, broken symlink detection, Plans symlink, and auto-generates an Obsidian index note with wikilinks."
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
- `/obsidian-link init` → **Init mode** (configure plan frontmatter)

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

## Preflight (runs before every mode)

Before executing any mode, silently check the current setup state. This takes a few seconds and informs how you interact with the user.

### Checks

| Check | How | States |
|-------|-----|--------|
| **Vault path** | `~/.obsidian-vault` file or `$OBSIDIAN_VAULT` | configured / missing |
| **Vault directory** | `<vault>/ClaudeCode/` exists | exists / missing |
| **Plans symlink** | `readlink ~/.claude/plans` | linked-to-vault / linked-elsewhere / missing |
| **Plan frontmatter** | Search `~/.claude/CLAUDE.md` for `## Plan Files` section | configured / missing |
| **Project linked** | `<vault>/ClaudeCode/Agents/<project>/` has symlinks | linked / not-linked |

### Behaviour

Summarise the setup state in a compact block before proceeding with the requested mode:

```
obsidian-link preflight:
  Vault:       /path/to/vault (OK)
  Plans:       ~/.claude/plans → vault (OK)
  Frontmatter: configured in CLAUDE.md (OK) | not configured
  Project:     <project> linked (6 agents, 2 skills) | not linked
```

Then, based on state and requested mode:

- **If vault path is missing** → Ask the user before continuing with any mode. Cannot proceed without it.
- **If frontmatter is not configured** and mode is `link` or `status` → Append a suggestion after the mode completes:
  > Tip: Run `/obsidian-link init` to configure plan frontmatter in your CLAUDE.md — plans will then be browsable in Obsidian with Dataview, tags, and graph view.
- **If frontmatter is not configured** and mode is `init` → Expected, proceed normally.
- **If frontmatter is already configured** and mode is `init` → Show current config in preflight, then Step 2 of Init mode handles the replace-or-keep flow.
- **If project is not linked** and mode is `status` → Note it in the status report, suggest running `/obsidian-link` to link.

The preflight should be lightweight and informational — never block a mode from running (except when vault path is missing). Its purpose is context, not gatekeeping.

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
    project-a  — 16 agents, 1 skill, 0 broken
    project-b  — 4 agents, 2 skills, 1 broken
      broken: project-b/old-agent.md → /path/that/moved

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

## Init Mode

Interactively configures `~/.claude/CLAUDE.md` so that Claude always adds Obsidian-friendly frontmatter when creating plan files. This is a one-time setup — safe to re-run (idempotent).

### Step 1: Resolve vault path

Same as Link mode. Needed to generate the correct `~/.claude/plans` symlink path in instructions.

### Step 2: Check for existing frontmatter instructions

Search `~/.claude/CLAUDE.md` for a `## Plan Files` section (or similar frontmatter block referencing `plans/`).

- **Found** → Show the user the current config, ask if they want to replace or keep it.
- **Not found** → Proceed to Step 3.

### Step 3: Ask the user about their frontmatter fields

Present a conversational prompt like:

> I'll add instructions to your global CLAUDE.md so plan files always get Obsidian-friendly frontmatter.
>
> Here are some common fields — which would you like?

**Default fields** (always included unless explicitly removed):
| Field | Example | Purpose |
|-------|---------|---------|
| `type` | `plan` | Obsidian note type for Dataview/queries |
| `title` | `User Auth OAuth Flow` | Human-readable title |
| `status` | `draft \| approved \| done` | Plan lifecycle tracking |
| `created` | `2026-03-05` | Creation date |
| `tags` | `[plan, <project>]` | Obsidian tag navigation |

**Optional fields** (suggest these, let user pick):
| Field | Example | Purpose |
|-------|---------|---------|
| `id` | `<project>-oauth-flow` | Unique slug for cross-referencing |
| `projects` | `[proj-<project>]` | Multi-project attribution |
| `priority` | `high \| medium \| low` | Prioritisation |
| `complexity` | `1-5` | Estimation (per user's preference) |
| `related` | `[[other-plan]]` | Wikilink to related plans |
| `linear` | `PROJ-123` | Linear/issue tracker reference |
| `updated` | `2026-03-05` | Last-modified date |

Let the user add, remove, or rename fields freely. They may also suggest entirely custom fields — accept any valid YAML key.

### Step 4: Ask about filename convention

Present the current convention (or a sensible default):

> **Filename format:** `<project>-<kebab-slug>.md` (3–6 words)
> e.g. `myapp-user-auth-oauth-flow.md`, `backend-stripe-billing-integration.md`
>
> Want to adjust this? (e.g. date prefix, different separator, no project prefix)

Accept the user's preference or confirm the default.

### Step 5: Generate the CLAUDE.md section

Build a `## Plan Files` section containing:
1. The filename convention
2. A YAML frontmatter template with the chosen fields
3. Brief inline comments showing example values

Example output (will vary based on user choices):

```markdown
## Plan Files

When writing plan files (in `~/.claude/plans/`, which symlinks to `ObsidianVault/Plans/`), always include this frontmatter so they're browsable in Obsidian:

Filename should be kebab-case, prefixed with the project name, 3-6 words total, reflecting the plan content. E.g. `myapp-user-auth-oauth-flow.md`, `backend-stripe-billing-integration.md`.

\```yaml
---
type: plan
id: <project>-<kebab-slug>
title: <human-readable title>
status: draft | approved | done
projects:
  - <project ID>
tags:
  - plan
  - <project tag>
created: "<YYYY-MM-DD>"
---
\```
```

### Step 6: Preview and confirm

Show the user the exact block that will be inserted (or will replace the existing block). Ask for confirmation before writing.

### Step 7: Write to CLAUDE.md

- If replacing an existing `## Plan Files` section: replace from `## Plan Files` to the next `##` heading (or end of file).
- If inserting new: add before the first `---` horizontal rule after the initial sections, or append before `# Code Style` if that heading exists. Use best judgement to place it logically.
- **Never overwrite unrelated sections.**

### Step 8: Report

```
obsidian-link init: complete

  CLAUDE.md: ~/.claude/CLAUDE.md updated
  Section:   ## Plan Files (inserted | replaced)
  Fields:    type, title, status, created, tags, id, projects
  Filename:  <project>-<kebab-slug>.md

  Plans will now include Obsidian frontmatter automatically.
```

---

## Notes

- **Never auto-delete broken symlinks** — report them and let the user decide
- **Never overwrite non-Obsidian configs** — if `~/.claude/agents` is a real directory, warn and skip
- **Idempotent by design** — running Link mode repeatedly produces the same result with accurate counts
- **Index note is disposable** — fully regenerated each run, safe to delete manually
