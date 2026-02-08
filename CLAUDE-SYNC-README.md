# Claude Code Sync Setup

## What's Synced
- `skills/` - Custom skills
- `agents/` - Custom agents
- `settings.json` - User settings
- `rules/` - Custom rules
- `CLAUDE.md` - Personal memory

## How It Works
Symlinks point `~/.claude/<item>` to `~/dotfiles/claude-sync/<item>`.

## Setup on New Machine

```bash
# Clone repo
git clone <your-repo-url> ~/dotfiles

# Create .claude directory
mkdir -p ~/.claude

# Create symlinks
ln -s ~/dotfiles/claude-sync/skills ~/.claude/skills
ln -s ~/dotfiles/claude-sync/agents ~/.claude/agents
ln -s ~/dotfiles/claude-sync/settings.json ~/.claude/settings.json
ln -s ~/dotfiles/claude-sync/rules ~/.claude/rules
ln -s ~/dotfiles/claude-sync/CLAUDE.md ~/.claude/CLAUDE.md
```

## Daily Workflow

**After creating/editing skills, agents, etc:**
```bash
cd ~/dotfiles
git add .
git commit -m "Update Claude config"
git push
```

**On other machine:**
```bash
cd ~/dotfiles
git pull
```

## Not Synced (Machine-Specific)
- `plugins/` - Install separately
- `projects/` - Auto-memory
- `cache/`, `debug/`, `history.jsonl`
