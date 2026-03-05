
<img alt="Screenshot 2026-03-05 at 07 05 29" src="https://github.com/user-attachments/assets/e1e88c1a-3b51-4235-b01e-567d924dd42e" />

# ObsidianSkills

Claude Code skills for bridging your Obsidian vault with Claude Code's configuration (agents, skills, plans).

## Why

Claude Code stores its configuration in dotfiles (`~/.claude/`, `.claude/` per repo). Obsidian is great for browsing, searching, and cross-referencing markdown. This skill connects the two — so you can see all your agents, skills, and plans in Obsidian's graph view, use Dataview queries across them, and author global skills directly in your vault.

**The core idea:** symlinks, not copies. Source files stay where they belong (repos for project config, vault for global config), and symlinks make them visible in the other location.

## Skills

### obsidian-link

Four modes, each idempotent and safe to re-run:

| Mode | Command | Purpose |
|------|---------|---------|
| **Link** | `/obsidian-link` | Connect current project's agents/skills to vault |
| **Status** | `/obsidian-link status` | Health check across all linked projects |
| **Unlink** | `/obsidian-link unlink <project>` | Remove a project's links from vault |
| **Init** | `/obsidian-link init` | Configure plan frontmatter in `~/.claude/CLAUDE.md` |

## Install

```bash
# Clone
git clone https://github.com/conorluddy/ObsidianSkills.git

# Symlink into Claude Code skills
ln -sf "$(pwd)/ObsidianSkills/obsidian-link" ~/.claude/skills/obsidian-link
```

## Configuration

Set your vault path via either:
1. `OBSIDIAN_VAULT` environment variable
2. `~/.obsidian-vault` file containing the absolute path

The skill confirms the path on first run and offers to save it.

## How It Works

### Directionality

The symlink direction depends on what owns the source file:

| Config type | Source of truth | Symlinked into |
|-------------|----------------|----------------|
| Per-project agents/skills | Project repo (`.claude/`) | Obsidian vault |
| Global agents/skills | Obsidian vault | `~/.claude/` |
| Plans | Obsidian vault | `~/.claude/plans` |

### Vault structure

Running `/obsidian-link` creates this in your vault:

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

### Preflight

Every mode starts with a quick preflight check that detects setup state:

```
obsidian-link preflight:
  Vault:       /path/to/vault (OK)
  Plans:       ~/.claude/plans -> vault (OK)
  Frontmatter: configured in CLAUDE.md (OK)
  Project:     myapp linked (6 agents, 2 skills)
```

If plan frontmatter isn't configured, the skill suggests running `/obsidian-link init`. If the vault path is missing, it asks before continuing.

## Modes

### Link (default)

```
/obsidian-link
```

1. Resolves vault path and ensures directory structure
2. Creates `~/.claude/plans` symlink to vault (if not already set)
3. Detects current project from git root
4. Symlinks project agents (`.claude/agents/*.md`) into vault
5. Symlinks project skills (`.claude/skills/*/`) into vault
6. Syncs global skills/agents from vault into `~/.claude/`
7. Detects and reports broken symlinks (never auto-deletes)
8. Regenerates the `ClaudeCode/README.md` index note with wikilinks

### Status

```
/obsidian-link status
```

Scans the vault's `ClaudeCode/` directories and reports health across all linked projects — agent/skill counts, broken symlinks, global sync state, plans symlink. Regenerates the index note.

### Unlink

```
/obsidian-link unlink <project>
```

Removes a project's symlinks from the vault. Asks for confirmation first. Source files in the repo are never touched — only the symlinks in the vault are deleted.

### Init

```
/obsidian-link init
```

Interactively configures `~/.claude/CLAUDE.md` so Claude always adds Obsidian-friendly YAML frontmatter when creating plan files. This means plans are browsable with Dataview queries, tags, and Obsidian's graph view.

The skill walks you through:
1. **Field selection** — choose from defaults (`type`, `title`, `status`, `created`, `tags`) and optional fields (`id`, `projects`, `priority`, `complexity`, `related`, `linear`, `updated`) or add your own
2. **Filename convention** — configure the naming pattern (default: `<project>-<kebab-slug>.md`)
3. **Preview and confirm** — see the exact CLAUDE.md section before it's written

Safe to re-run — detects existing config and offers to update or keep it.

## Safety

- **Never auto-deletes** — broken symlinks are reported, not removed
- **Never overwrites** — existing non-Obsidian configs (real directories, symlinks to other locations) are warned about and skipped
- **Idempotent** — every mode produces the same result regardless of how many times it runs
- **Source files untouched** — unlink only removes symlinks in the vault, never repo files

## License

MIT
