# Claude and Codex instruction sync

This repo syncs **only `claude-sync/AGENTS.md`** as the canonical global instruction
file across machines. Claude Code and Codex use small machine-local loaders that point
to that file. Everything else — settings, statuslines, plugins, skills, conversations,
and authentication — is **machine-local** and managed by hand.

> Consolidating another machine off the old multi-account (`CLAUDE_CONFIG_DIR`) setup?
> See `CLAUDE-CONSOLIDATION-RUNBOOK.md` — it pins the initial/final states so Claude
> Code can generate a tailored migration script on that machine.

> Simplified 2026-06-27. Previously this repo also symlinked `settings.json`,
> `skills/`, `rules/`, `agents/`, `commands/` into `~/.claude`; that got brittle, so
> it was dropped. See `SKILLS-I-HAD.md` for the old skill list and
> `CONVERSATIONS-BACKUP.md` for the conversation snapshot.

## What syncs
- `claude-sync/AGENTS.md` — the only Git-tracked shared instruction file.
- `~/.codex/AGENTS.md` — a machine-local symlink to the canonical file.
- `~/.claude/CLAUDE.md` — a machine-local wrapper that imports the canonical file,
  then imports Claude-only `~/.claude/RTK.md`.

Edit shared instructions only in `~/dotfiles/claude-sync/AGENTS.md`. Do not duplicate
them in either machine-local loader.

## What is machine-local (NOT synced)
- `~/.claude/settings.json` — real local file (statusline, plugins, hooks, theme).
- `~/.claude/statusline-command.sh` — real local script (referenced by settings).
- `~/.claude/skills/` — install/copy skills yourself (see `SKILLS-I-HAD.md`).
- `~/.claude/settings.local.json`, `projects/`, `history*`, `todos/`, `sessions/`,
  `plugins/`, `.claude.json` — per-machine state, never synced.

## Config directory
Claude Code uses the default `~/.claude`. Do **not** set `CLAUDE_CONFIG_DIR` —
that's what created the old multi-account mess (`~/.claude-account1`, since removed
on 2026-06-27). If `claude` ever points at the wrong place, check:
`echo $CLAUDE_CONFIG_DIR` — it should be empty.

## Setup on a new machine
```bash
git clone git@github.com:mostafa-ghaith/dotfiles.git ~/dotfiles
mkdir -p ~/.claude ~/.codex

rm -f ~/.codex/AGENTS.md
ln -s ~/dotfiles/claude-sync/AGENTS.md ~/.codex/AGENTS.md

rm -f ~/.claude/CLAUDE.md
printf '@../dotfiles/claude-sync/AGENTS.md\n\n@RTK.md\n' > ~/.claude/CLAUDE.md
```
Then start new Claude and Codex sessions. Set up authentication, settings, and skills
locally as needed.

Verify the loaders:
```bash
readlink ~/.codex/AGENTS.md
sed -n '1,5p' ~/.claude/CLAUDE.md
```

The Codex path should resolve to `~/dotfiles/claude-sync/AGENTS.md`. The Claude file
should contain only the two imports shown above. If RTK is not installed on that machine,
remove the `@RTK.md` line.

## Auto-sync
`~/.claude/settings.json` has `SessionStart` / `SessionEnd` hooks that
`git pull` / `git commit + push` `~/dotfiles` automatically. Manually:
```bash
cd ~/dotfiles && git pull
cd ~/dotfiles && git add claude-sync/AGENTS.md && git commit -m "Update global instructions" && git push
```
