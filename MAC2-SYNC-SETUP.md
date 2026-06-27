# Claude Code Sync — Second-Machine Setup (single account)

How to bring a second Mac into sync. As of 2026-06-27 the setup is a **single
account**: one config dir `~/.claude`, launched by plain `claude` (no aliases).

Repo: `git@github.com:mostafa-ghaith/dotfiles.git` (personal account `mostafa-ghaith`).

See `CLAUDE-SYNC-README.md` for the full reference of what syncs and why.

---

## Case A — Mac2 still has the OLD multi-account layout

If Mac2 has `~/.claude-account1` / `~/.claude-account2` (or the even older
`~/.claude-account-crop` / `~/.claude-account-personal`), just run the migration
script — it handles renaming-tolerant detection, merging, and cleanup:

```bash
git clone git@github.com:mostafa-ghaith/dotfiles.git ~/dotfiles 2>/dev/null \
  || (cd ~/dotfiles && git pull)
bash ~/dotfiles/claude-sync/consolidate.sh      # plain terminal, ALL Claude sessions closed
```

What it does (idempotent, backs up first to `~/claude-consolidate-backup-*.tar.gz`):
1. Merges all accounts' `projects/` + `history*` + `todos/` into `~/.claude`.
2. Copies the **corp** `.claude.json` to `~/.claude.json` (keeps corp login/state).
3. Symlinks the synced config (`settings.json`, `CLAUDE.md`, `skills`, `rules`,
   `agents`, `commands`) into `~/.claude`.
4. Removes RTK and the `claude` / `claudeMG` aliases from `~/.zshrc`.
5. Deletes `~/.claude-account1`, `~/.claude-account2`, `~/.claude-primary`.

Then open a new terminal and run `claude`. If it isn't logged into the corp
account, run `/login` once (conversations/settings are unaffected).

---

## Case B — Mac2 is fresh (no Claude config yet)

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
Then run `claude`, log in as corp, and let plugins auto-install on first launch.
Requires `~/.local/bin` on PATH (else `alias claude='~/.local/bin/claude'`), plus
`jq` and `git`.

---

## Verify
```bash
# symlinks resolve to dotfiles:
ls -la ~/.claude | grep -E 'settings.json|CLAUDE.md|skills'
# settings valid + plugin/marketplace counts:
jq '{plugins:(.enabledPlugins|keys|length), marketplaces:(.extraKnownMarketplaces|keys)}' \
  ~/.claude/settings.json
# logged-in account:
jq '.oauthAccount | {email:.emailAddress, org:.organizationName}' ~/.claude.json
```
Open `/hooks` in a session to confirm the SessionStart/SessionEnd dotfiles-sync hooks load.

## Caveats
- Hooks, plugins, and `git pull` take effect on the **next** session start, not the
  running one (config is read once at launch).
- Conversations are **machine-local** — they do not sync between Macs. Only the
  config in `claude-sync/` syncs.
- If a non-official plugin ever fails to auto-install, run once:
  `/plugin marketplace add eigenpal/docx-template-skill` (and `davila7/claude-code-templates`,
  `mvanhorn/last30days-skill`).
- Two `gh` accounts may be authenticated; pushes to this repo go over SSH to
  `mostafa-ghaith` — verify the active account before unrelated `gh`/git work.

## Daily workflow
The hooks automate it; manually:
```bash
cd ~/dotfiles && git pull
cd ~/dotfiles && git add -A && git commit -m "…" && git push
```
