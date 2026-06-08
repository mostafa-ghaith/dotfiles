# Claude Code Sync Setup

Syncs portable Claude Code config across machines and across all three config
directories used on each machine.

## Config directories (per machine)
Claude Code uses whatever `CLAUDE_CONFIG_DIR` points to, else `~/.claude`.

| Dir | Launched by | Account |
|-----|-------------|---------|
| `~/.claude` | `claude` with NO alias (IDE/app/direct binary) | default |
| `~/.claude-account1` | `claude` alias (`CLAUDE_CONFIG_DIR=~/.claude-account1`) | corp |
| `~/.claude-account2` | `claudeMG` alias (`CLAUDE_CONFIG_DIR=~/.claude-account2`) | personal |

All three symlink the shared items below to `~/dotfiles/claude-sync/`.

## What's synced (portable, read-mostly)
- `settings.json` — user settings + `enabledPlugins` (this is how plugin *enablement* syncs)
- `CLAUDE.md` — global memory / profile (identical for all accounts)
- `skills/` — custom skills
- `statusline-command.sh` — referenced by settings via `~/dotfiles/claude-sync/...` (portable path)

`agents/` and `rules/` are currently empty — add them to the link loop below once they have content.

## What's NOT synced (machine/account-specific — do NOT sync)
- `settings.local.json` — per-account permissions/overrides
- `sessions/`, `history.jsonl` — embed absolute paths, written constantly, conflict across machines
- `projects/` — session transcripts + auto-memory, tied to absolute repo paths, machine-local
- `plugins/` cache and `.claude.json` — installed-plugin cache + auth/MCP state, machine-local

## Plugins — fully synced via settings.json
Two keys in the synced `settings.json` together define the full plugin set; the
plugin *code* is NOT synced — each machine fetches its own copy from the declared
sources (avoids repo bloat, stale code, and concurrent-cache corruption):
- `enabledPlugins` — which plugins are on.
- `extraKnownMarketplaces` — where to fetch the non-official ones (`eigenpal`,
  `claude-code-templates`). The built-in `claude-plugins-official` needs no entry.

Result: a fresh machine/account that loads this settings.json knows both *which*
plugins to enable and *where* to get them, and installs them automatically — no
manual `/plugin marketplace add`. Takes effect on next session start (not the
already-running one). Adding a new plugin later: enable it, and if it's from a new
marketplace, add that marketplace to `extraKnownMarketplaces`.

## Setup on a new machine
```bash
git clone git@github.com:mostafa-ghaith/dotfiles.git ~/dotfiles
DOT=~/dotfiles/claude-sync
for ACC in ~/.claude ~/.claude-account1 ~/.claude-account2; do
  mkdir -p "$ACC"
  for item in settings.json CLAUDE.md skills; do
    rm -rf "$ACC/$item"
    ln -s "$DOT/$item" "$ACC/$item"
  done
done
chmod +x "$DOT/statusline-command.sh"
# then add the two marketplaces (above) once per account
```
Make sure the shell aliases exist (`~/.zshrc`):
```bash
alias claude='CLAUDE_CONFIG_DIR=~/.claude-account1 ~/.local/bin/claude'
alias claudeMG='CLAUDE_CONFIG_DIR=~/.claude-account2 ~/.local/bin/claude'
```

## Daily workflow
```bash
cd ~/dotfiles && git add -A && git commit -m "Update Claude config" && git push   # after edits
cd ~/dotfiles && git pull                                                          # on the other Mac
```
Because items are symlinked, editing them in any account dir edits the dotfiles copy directly.
