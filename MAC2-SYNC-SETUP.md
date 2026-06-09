# Claude Code Sync — Summary & Second-Machine Setup

Snapshot of how Claude Code config is synced via this `dotfiles` repo, and the exact
steps to bring a second Mac into sync.

Repo: `git@github.com:mostafa-ghaith/dotfiles.git` (personal account `mostafa-ghaith`).

---

## 1. What was set up

### Config directories (per machine)
Claude Code uses `CLAUDE_CONFIG_DIR` if set, else `~/.claude`. There are **three**,
all sharing the same synced files:

| Dir | Launched by | Account |
|-----|-------------|---------|
| `~/.claude` | `claude` with no alias (IDE / app / direct binary) | default |
| `~/.claude-account1` | `claude` alias (`CLAUDE_CONFIG_DIR=~/.claude-account1`) | corp |
| `~/.claude-account2` | `claudeMG` alias (`CLAUDE_CONFIG_DIR=~/.claude-account2`) | personal |

Shell aliases (`~/.zshrc`):
```bash
alias claude='CLAUDE_CONFIG_DIR=~/.claude-account1 ~/.local/bin/claude'
alias claudeMG='CLAUDE_CONFIG_DIR=~/.claude-account2 ~/.local/bin/claude'
```

### What's synced (symlinked from `~/dotfiles/claude-sync/` into all three dirs)
- `settings.json` — see breakdown below
- `CLAUDE.md` — global profile/memory, identical for all accounts
- `skills/` — custom skills only: `api-schema-reviewer`, `langgraph-agent-development`
- `statusline-command.sh` — referenced by settings via a portable `~/dotfiles/...` path

### What `settings.json` contains
- `permissions.defaultMode: auto`, push-notif + skip flags, `effortLevel: high`
- `statusLine` → `bash ~/dotfiles/claude-sync/statusline-command.sh`
- **Hooks:**
  - `SessionStart` → `git pull --rebase --autostash` in `~/dotfiles` (async, non-blocking)
  - `SessionEnd` → commit-if-changed + pull + push `~/dotfiles` (tagged with hostname)
- **Plugins (fully defined here):**
  - `enabledPlugins` — 14 plugins
  - `extraKnownMarketplaces` — `eigenpal`, `claude-code-templates` (official is built-in)

### What is NOT synced (intentionally — machine/account-specific)
- `settings.local.json` — per-account permissions/overrides
- `sessions/`, `history.jsonl`, `projects/` — absolute paths, constant writes, conflict-prone
- `plugins/` cache and `.claude.json` — plugin *code* + auth/MCP state (each machine fetches its own)

### Key principle for plugins
The plugin **definition** (which + where) is synced via `settings.json`. The plugin
**code** is not — each machine auto-installs from the declared marketplaces on first launch.
This avoids repo bloat, nested git repos, and cache corruption.

---

## 2. Setup on the second Mac

> Assumes the same macOS username and `~/.local/bin/claude` install. Paths use `~`,
> so a different username is fine for the symlinks; only the project paths *inside*
> `CLAUDE.md` are written for `/Users/Mostafa`.

### Step 1 — Get the repo
```bash
# fresh:
git clone git@github.com:mostafa-ghaith/dotfiles.git ~/dotfiles
# or if it already exists:
cd ~/dotfiles && git pull
```

### Step 2 — Standardize the account dir names
The second Mac currently uses `~/.claude-account-crop` and `~/.claude-account-personal`.
Rename them to match (back up first if unsure):
```bash
mv ~/.claude-account-crop     ~/.claude-account1   # corp
mv ~/.claude-account-personal ~/.claude-account2   # personal
```

### Step 3 — Back up any existing per-account settings (optional but safe)
```bash
for ACC in ~/.claude ~/.claude-account1 ~/.claude-account2; do
  [ -e "$ACC/settings.json" ] && [ ! -L "$ACC/settings.json" ] && \
    cp "$ACC/settings.json" "$ACC/settings.json.bak-$(date +%Y%m%d-%H%M%S)"
done
```

### Step 4 — Symlink the shared items into all three dirs
```bash
DOT=~/dotfiles/claude-sync
for ACC in ~/.claude ~/.claude-account1 ~/.claude-account2; do
  mkdir -p "$ACC"
  for item in settings.json CLAUDE.md skills; do
    rm -rf "$ACC/$item"
    ln -s "$DOT/$item" "$ACC/$item"
  done
done
chmod +x "$DOT/statusline-command.sh"
```

### Step 5 — Ensure the aliases exist (`~/.zshrc`)
```bash
alias claude='CLAUDE_CONFIG_DIR=~/.claude-account1 ~/.local/bin/claude'
alias claudeMG='CLAUDE_CONFIG_DIR=~/.claude-account2 ~/.local/bin/claude'
```
Then `source ~/.zshrc`.

### Step 6 — Launch and let plugins install
Start `claude` (corp) and `claudeMG` (personal). On first launch each reads the synced
`settings.json`, sees the 14 enabled plugins + marketplaces, and installs them automatically.
`jq` and `git` must be installed (statusline + hooks use them).

---

## 3. Verify
```bash
# symlinks resolve:
ls -la ~/.claude-account1 | grep -E 'settings.json|CLAUDE.md|skills'
# settings valid + plugin counts:
jq '{plugins:(.enabledPlugins|keys|length), marketplaces:(.extraKnownMarketplaces|keys)}' \
  ~/.claude-account1/settings.json
```
Open `/hooks` in a session to confirm the SessionStart/SessionEnd hooks are loaded.

---

## 4. Caveats
- **Hooks, plugins, and `git pull` take effect on the *next* session start**, not the one
  already running (Claude reads config once at launch).
- `extraKnownMarketplaces` is documented as "typically" a project-settings key; if a fresh
  machine ever doesn't auto-install a non-official plugin, run once per account:
  `/plugin marketplace add eigenpal/docx-template-skill` (and `davila7/claude-code-templates`).
- Two `gh` accounts are authenticated on these machines — pushes to this repo go over SSH
  to `mostafa-ghaith`; verify the active account before unrelated `gh`/git work.

---

## 5. Daily workflow (after setup)
The hooks automate this, but manually:
```bash
cd ~/dotfiles && git pull                         # start of work / new machine
cd ~/dotfiles && git add -A && git commit -m "…" && git push   # after config edits
```
Because items are symlinked, editing a skill / `CLAUDE.md` / `settings.json` in any
account edits the dotfiles copy directly.
