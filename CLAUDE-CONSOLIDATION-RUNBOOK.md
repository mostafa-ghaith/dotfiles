# Claude Code consolidation runbook

How to collapse a multi-account Claude Code setup (the `CLAUDE_CONFIG_DIR`
alias mess) down to a single `~/.claude` on a machine. This Mac was done on
**2026-06-27**; this runbook exists so the **other PC** can reach the same final state.

## How to run this on the other PC

1. `git clone`/`git pull` this repo to `~/dotfiles` on that machine.
2. Start Claude Code there and tell it: **"Read `~/dotfiles/CLAUDE-CONSOLIDATION-RUNBOOK.md`
   and consolidate this machine to the final state."**
3. Claude inspects *that machine's actual state* (which account dirs exist, what the
   aliases are, which account holds the real history) and **writes a tailored script**
   to reach the Final State below. Don't blindly reuse this Mac's commands — the other
   PC likely has **both** `account1` and `account2` dirs, where this Mac only had `account1`.
4. **Destructive deletes are print-don't-run.** The script does all the safe steps
   (backup, snapshot, strip aliases, symlink) automatically, then *prints* the
   `rm -rf` commands. You run those by hand only after verifying the backup and login.

---

## Initial state — the mess (what to expect)

Two shell aliases force `claude` into separate config dirs (this is the root cause —
recovered from `~/.zshrc.pre-consolidate-20260627-091541` on this Mac):

```zsh
alias claude='CLAUDE_CONFIG_DIR=~/.claude-account1 ~/.local/bin/claude'
alias claudeMG='CLAUDE_CONFIG_DIR=~/.claude-account2 ~/.local/bin/claude'
```

So the machine has up to **three** config dirs:

| Dir | How it was reached | Notes |
|---|---|---|
| `~/.claude` | plain `claude` with no alias / no env | the default; the **keeper** |
| `~/.claude-account1` | `claude` alias | leftover |
| `~/.claude-account2` | `claudeMG` alias | leftover (may or may not exist) |

All three were the **same login** here (`m.ghaith@edecs.com` / Edecs) — verify per machine
via `oauthAccount.emailAddress` in each dir's `.claude.json`. **Don't assume.** On the
other PC the real conversation history might live inside `account1` or `account2`, not
the default `~/.claude`.

---

## Final state — the target (verified on this Mac)

- **One** config dir: `~/.claude`. No `~/.claude-account*` dirs.
- `~/.claude/CLAUDE.md` is a symlink → `~/dotfiles/claude-sync/CLAUDE.md` (the only synced file).
- `CLAUDE_CONFIG_DIR` is **empty/unset** everywhere (no alias, no `export`).
- `type claude` → `/Users/<you>/.local/bin/claude` (a real binary, **not** an alias).
- `~/.zshrc` has **zero** claude references.
- Old conversations are preserved in a backup dir (see "Conversations backup" below);
  the live `~/.claude` keeps its own `projects/`.

### Verification checklist (run in a fresh shell after migrating)
```bash
echo "[$CLAUDE_CONFIG_DIR]"          # -> []   (empty)
type claude                          # -> .../.local/bin/claude  (NOT 'aliased to ...')
grep -ni claude ~/.zshrc             # -> no CLAUDE_CONFIG_DIR / no claude alias lines
ls -ld ~/.claude-account*            # -> no matches found
readlink ~/.claude/CLAUDE.md         # -> ~/dotfiles/claude-sync/CLAUDE.md
claude   # launch, confirm it's the account you intend to keep
```

---

## What the tailored script must do (in order)

1. **Back up first (never skip).**
   - `cp ~/.zshrc ~/.zshrc.pre-consolidate-<timestamp>`
   - `tar czf ~/claude-consolidate-backup-<timestamp>.tar.gz` of every `~/.claude*` dir.
   - Snapshot conversations → `~/claude-backups/` (see structure below).
2. **Pick the keeper.** Inspect login + `projects/` size in `~/.claude`,
   `~/.claude-account1`, `~/.claude-account2`. Keeper = the dir with the login + history
   you want. If the keeper is **not** the default `~/.claude`, merge its `projects/`,
   `history.jsonl`, etc. into `~/.claude` before deleting.
3. **Strip the aliases.** Remove the `alias claude=...` and `alias claudeMG=...` lines
   from `~/.zshrc` (and `~/.zprofile`/`~/.bashrc` if present). Ensure no global
   `export CLAUDE_CONFIG_DIR`.
4. **Set up the symlink.**
   ```bash
   mkdir -p ~/.claude
   rm -f ~/.claude/CLAUDE.md
   ln -s ~/dotfiles/claude-sync/CLAUDE.md ~/.claude/CLAUDE.md
   ```
5. **Verify** (checklist above) in a *new* shell.
6. **Print (do not run) the deletes** for the user to paste after verifying:
   ```bash
   # rm -rf ~/.claude-account1 ~/.claude-account2
   # rm ~/claude-consolidate-backup-<timestamp>.tar.gz   # after you're happy (large)
   ```

---

## Conversations backup (combined + searchable)

The transcripts are **not** in git on purpose (this Mac's snapshot is ~390 MB; git is the
wrong store). They live machine-local under `~/claude-backups/` so Claude can search them
on instruction.

### Structure (one dir per consolidation run)
```
~/claude-backups/conversations-<machine>-<YYYY-MM-DD>/
├── default-claude/   # from ~/.claude        (projects/, sessions/, history.jsonl)
├── account1/         # from ~/.claude-account1
└── account2/         # from ~/.claude-account2   (if it existed)
```
This Mac's snapshot: `~/claude-backups/conversations-2026-06-27/` (`default-claude/` + `account1/`).

### Making them *combined* across both Macs
Each Mac keeps its own `conversations-<machine>-<date>/` dir. To search across both from
one place, copy the other Mac's dir into this Mac's `~/claude-backups/` (AirDrop / rsync /
drive). All `conversations-*` dirs then sit side by side under `~/claude-backups/`.

### How to search them
Just tell Claude, e.g. *"search my old Claude conversations for <topic>"*. Claude looks in
`~/claude-backups/` and greps the transcripts:
```bash
grep -rli "some phrase" ~/claude-backups/                      # which transcripts match
ls ~/claude-backups/*/*/projects                               # list project folders
# each projects/<encoded-dir>/*.jsonl is a full transcript for a working directory
```

---

See also: `CLAUDE-SYNC-README.md` (sync model + fresh-machine setup),
`CONVERSATIONS-BACKUP.md` (this Mac's snapshot), `SKILLS-I-HAD.md` (skill inventory).
