
<img alt="Screenshot 2026-03-05 at 07 05 29" src="https://github.com/user-attachments/assets/e1e88c1a-3b51-4235-b01e-567d924dd42e" />

# ObsidianSkills

Claude Code skills for bridging your Obsidian vault with Claude Code's configuration (agents, skills, plans).

## Skills

### obsidian-link

Link a project's Claude Code agents and skills into your Obsidian vault for browsing and cross-referencing.

**Install:**
```bash
# Clone the repo
git clone https://github.com/conorluddy/ObsidianSkills.git

# Symlink the skill into your Claude Code skills directory
ln -sf "$(pwd)/ObsidianSkills/obsidian-link" ~/.claude/skills/obsidian-link
```

**Usage:**

```
/obsidian-link              # Link current project to your vault (default)
/obsidian-link status       # Health check across all linked projects
/obsidian-link unlink app   # Remove a project's links from the vault
```

**What it does:**

- Links project-specific agents and skills into your Obsidian vault as symlinks
- Syncs global Obsidian-authored skills/agents into `~/.claude/`
- Creates a `ClaudeCode/` directory in your vault with `Agents/`, `Skills/`, and `Plans/` subdirectories
- Detects broken symlinks and reports them without auto-deleting
- Generates an index note with wikilinks for Obsidian's graph view
- Idempotent — safe to run repeatedly

**Configuration:**

Set your vault path via:
1. `OBSIDIAN_VAULT` environment variable, or
2. `~/.obsidian-vault` file containing the absolute path

The skill will confirm the path with you on first run and offer to save it.

## Philosophy

Obsidian is a great authoring surface for prompt-heavy markdown. This repo treats your vault as the central place to browse, search, and cross-reference all your Claude Code configuration — while keeping project-specific files in their repos where they belong.

- **Global agents/skills**: Author in Obsidian, symlinked into `~/.claude/`
- **Per-project agents/skills**: Live in the repo, symlinked into Obsidian for browsing

## License

MIT
