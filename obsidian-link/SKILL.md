---
name: obsidian-link
description: Link a project's Claude Code agents and skills into an Obsidian vault for browsing and cross-referencing. Use when the user says /obsidian-link, wants to connect their repo to Obsidian, or wants to browse project agents/skills in their vault.
---

# obsidian-link

Connect a project's Claude Code configuration (agents, skills) to an Obsidian vault so everything is browsable, searchable, and cross-referenceable from one place.

The linking is directional by design:
- **Global agents/skills**: Obsidian is source of truth, symlinked into `~/.claude/`
- **Per-project agents/skills**: Project repo is source of truth, symlinked into Obsidian

## Configuration

The skill needs to know where the user's Obsidian vault lives.

### Resolving the vault path

Check in order:
1. `OBSIDIAN_VAULT` environment variable
2. `~/.obsidian-vault` file (a single line containing the absolute vault path)

If a path is found from either source, **confirm it with the user** before proceeding. A `.obsidian/` directory inside the path is a good signal it's a vault, but don't rely on this alone.

If no path is found, ask the user for their vault location.

Once confirmed, offer to save the path to `~/.obsidian-vault` so future runs skip the question.

### Directory structure

The skill creates a `ClaudeCode/` directory inside the vault:

```
<vault>/ClaudeCode/
  ├── Agents/
  │   ├── global/       # Obsidian-authored, symlinked INTO ~/.claude/agents/
  │   └── <project>/    # Symlinks pointing INTO project repos
  ├── Skills/
  │   ├── global/       # Obsidian-authored, symlinked INTO ~/.claude/skills/
  │   └── <project>/    # Symlinks pointing INTO project repos
  └── Plans/            # Symlinked from ~/.claude/plans
```

## Steps

### 1. Resolve and confirm vault path

Follow the resolution order above. Always confirm with the user.

### 2. Ensure the ClaudeCode directory structure exists

```bash
mkdir -p "<vault>/ClaudeCode/Agents/global"
mkdir -p "<vault>/ClaudeCode/Skills/global"
mkdir -p "<vault>/ClaudeCode/Plans"
```

### 3. Detect the current project

Run `git rev-parse --show-toplevel` to get the repo root.
Extract the basename as the project name, lowercased.

If not in a git repo, ask the user for a project name and root path.

### 4. Link project agents into Obsidian

Check if `<repo-root>/.claude/agents/` exists. If not, ask the user if they want to create it.

If it exists (or was just created):

```bash
mkdir -p "<vault>/ClaudeCode/Agents/<project>"
```

For each `.md` file in the project's `.claude/agents/`, create a symlink in Obsidian pointing to the project file:
```bash
ln -sf "<repo-root>/.claude/agents/<file>" "<vault>/ClaudeCode/Agents/<project>/<file>"
```

### 5. Link project skills into Obsidian

Check if `<repo-root>/.claude/skills/` exists. If not, ask the user if they want to create it.

If it exists (or was just created):

```bash
mkdir -p "<vault>/ClaudeCode/Skills/<project>"
```

For each skill directory in the project's `.claude/skills/`, create a symlink in Obsidian pointing to the project directory:
```bash
ln -sf "<repo-root>/.claude/skills/<skill-name>" "<vault>/ClaudeCode/Skills/<project>/<skill-name>"
```

### 6. Sync global Obsidian-authored skills into ~/.claude

Scan `<vault>/ClaudeCode/Skills/global/` for skill directories (directories containing a `SKILL.md`).

For each one without a corresponding entry in `~/.claude/skills/`:
```bash
ln -sf "<vault>/ClaudeCode/Skills/global/<skill-name>" "$HOME/.claude/skills/<skill-name>"
```

Skip any that already exist — never overwrite non-Obsidian skills.

### 7. Sync global Obsidian-authored agents into ~/.claude

If `~/.claude/agents` doesn't exist, create it as a symlink to the global agents directory:
```bash
ln -sf "<vault>/ClaudeCode/Agents/global" "$HOME/.claude/agents"
```

If it already exists as a symlink pointing to the right place, skip.
If it exists as a real directory, warn the user and skip — don't clobber existing configs.

### 8. Report

Print a summary:
- Vault path used
- Project name and root path
- Agents linked (count and names)
- Skills linked (count and names)
- Global skills/agents synced or skipped
- Any warnings (directories created, items skipped, etc.)

## Example output

```
Linked my-app to Obsidian vault

  Vault:   ~/my-vault
  Project: my-app (~/projects/my-app)

  Agents: 2 linked
    - swift-ui-expert.md
    - data-engineer.md

  Skills: 1 linked
    - seed-data/

  Global sync:
    - obsidian-link already in ~/.claude/skills/ (skipped)
    - save-plan already in ~/.claude/skills/ (skipped)

  All browsable in Obsidian under ClaudeCode/
```
