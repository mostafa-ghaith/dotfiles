# Claude Code Sync Setup

Syncs portable Claude Code config across machines via this `dotfiles` repo.

**Single account (corp).** One config dir — `~/.claude` — used by plain `claude`
(no `CLAUDE_CONFIG_DIR`, no aliases).

> Migrated 2026-06-27 from the old 3-dir / 2-alias layout
> (`~/.claude` + `~/.claude-account1` + `~/.claude-account2`). To migrate a
> machine that still has the old layout, run
> [`claude-sync/consolidate.sh`](#migrating-a-machine-off-the-old-multi-account-setup).

## Config directory
Claude Code uses `~/.claude` (the default, since no `CLAUDE_CONFIG_DIR` is set).
It symlinks the shared items below to `~/dotfiles/claude-sync/`. State lives in
`~/.claude.json`.

## What's synced (portable, read-mostly)
- `settings.json` — user settings + `enabledPlugins` (+ `extraKnownMarketplaces`)
- `CLAUDE.md` — global memory / profile
- `skills/` — custom skills
- `rules/`, `agents/`, `commands/` — linked if present in `claude-sync/`
- `statusline-command.sh` — referenced by settings via a portable `~/dotfiles/...` path

## What's NOT synced (machine-local — do NOT sync)
- `settings.local.json` — per-machine permissions/overrides
- `projects/`, `history*`, `todos/`, `shell-snapshots/` — transcripts + auto-memory,
  embed absolute paths, written constantly, conflict-prone across machines
- `plugins/` cache and `.claude.json` — plugin code cache + auth/MCP state; each
  machine fetches/holds its own

## Plugins — defined via settings.json
Two keys in the synced `settings.json` fully define the plugin set; the plugin
*code* is fetched per-machine on first launch (avoids repo bloat / cache corruption):
- `enabledPlugins` — which plugins are on.
- `extraKnownMarketplaces` — where to fetch the non-official ones (`eigenpal`,
  `claude-code-templates`, `last30days-skill`). The official marketplace is built-in.

## Setup on a NEW machine (fresh, single account)
```bash
git clone git@github.com:mostafa-ghaith/dotfiles.git ~/dotfiles
DOT=~/dotfiles/claude-sync
mkdir -p ~/.claude
for item in settings.json CLAUDE.md skills rules agents commands; do
  [ -e "$DOT/$item" ] || continue
  rm -rf ~/.claude/"$item"
  ln -s "$DOT/$item" ~/.claude/"$item"
done
chmod +x "$DOT/statusline-command.sh"
```
No aliases needed — run `claude`. (Requires `~/.local/bin` on PATH; otherwise add
`alias claude='~/.local/bin/claude'`.) `jq` + `git` must be installed (hooks/statusline use them).

## Migrating a machine off the old multi-account setup
On each machine that still has `~/.claude-account1` / `~/.claude-account2`:
```bash
cd ~/dotfiles && git pull
bash ~/dotfiles/claude-sync/consolidate.sh   # plain terminal, ALL Claude sessions closed
```
It merges every account's conversations into `~/.claude`, adopts the corp
login/state, links the synced config, drops RTK + the aliases, and deletes the old
account dirs — after writing a full backup tarball to `~/claude-consolidate-backup-*`.

> Conversations are machine-local and do NOT sync between Macs — each machine keeps
> its own history. Only the config above syncs.

## Daily workflow
The `SessionStart` / `SessionEnd` hooks in `settings.json` auto pull / commit+push
`~/dotfiles`. Manually:
```bash
cd ~/dotfiles && git pull                                              # start of work
cd ~/dotfiles && git add -A && git commit -m "Update Claude config" && git push   # after edits
```
Because the items are symlinked, editing a skill / `CLAUDE.md` / `settings.json` in
`~/.claude` edits the dotfiles copy directly.
