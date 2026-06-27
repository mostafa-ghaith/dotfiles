# Claude Code sync

This repo syncs **only `CLAUDE.md`** (the global memory/profile) across machines.
Everything else — `settings.json`, the statusline, plugins, skills, conversations —
is **machine-local** and managed by hand.

> Consolidating another machine off the old multi-account (`CLAUDE_CONFIG_DIR`) setup?
> See `CLAUDE-CONSOLIDATION-RUNBOOK.md` — it pins the initial/final states so Claude
> Code can generate a tailored migration script on that machine.

> Simplified 2026-06-27. Previously this repo also symlinked `settings.json`,
> `skills/`, `rules/`, `agents/`, `commands/` into `~/.claude`; that got brittle, so
> it was dropped. See `SKILLS-I-HAD.md` for the old skill list and
> `CONVERSATIONS-BACKUP.md` for the conversation snapshot.

## What syncs
- `claude-sync/CLAUDE.md` → symlinked to `~/.claude/CLAUDE.md`.

That's it. Editing `~/.claude/CLAUDE.md` edits this repo's copy directly.

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
mkdir -p ~/.claude
rm -rf ~/.claude/CLAUDE.md
ln -s ~/dotfiles/claude-sync/CLAUDE.md ~/.claude/CLAUDE.md
```
Then run `claude`, log in, and set up `settings.json` / skills locally as you like.

## Auto-sync
`~/.claude/settings.json` has `SessionStart` / `SessionEnd` hooks that
`git pull` / `git commit + push` `~/dotfiles` automatically. Manually:
```bash
cd ~/dotfiles && git pull
cd ~/dotfiles && git add -A && git commit -m "Update CLAUDE.md" && git push
```
