#!/usr/bin/env bash
#
# consolidate.sh — Collapse the old multi-account Claude Code setup
#   ~/.claude  +  ~/.claude-account1  +  ~/.claude-account2  [+ ~/.claude-primary]
# into a single, normal ~/.claude.
#
#   • Merges ALL conversations + history into ~/.claude
#   • Adopts the CORP account's .claude.json (login + state) as ~/.claude.json
#   • Points ~/.claude config at the synced ~/dotfiles/claude-sync files
#   • Removes RTK (dropped) and the multi-account shell aliases
#   • Deletes the old account dirs — AFTER a full backup tarball
#
# Idempotent (safe to re-run).
#
# ⚠️  RUN FROM A PLAIN TERMINAL WITH ALL CLAUDE CODE SESSIONS CLOSED.
#     Do NOT run it via `!` inside a Claude session — that session is using one
#     of the directories this script moves/deletes.
#
set -euo pipefail

DOT="$HOME/dotfiles/claude-sync"
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/claude-consolidate-backup-$TS"

# --- locate account dirs (Mac2 may still use the older -crop/-personal names) ---
CORP=""
for c in "$HOME/.claude-account1" "$HOME/.claude-account-crop"; do
  [ -d "$c" ] && { CORP="$c"; break; }
done
PERSONAL=""
for p in "$HOME/.claude-account2" "$HOME/.claude-account-personal"; do
  [ -d "$p" ] && { PERSONAL="$p"; break; }
done

echo "Consolidate Claude Code into a single ~/.claude"
echo "  corp  (keep login/state) : ${CORP:-<none found>}"
echo "  personal (merge convos)  : ${PERSONAL:-<none found>}"
echo "  default ~/.claude        : merge convos, becomes the final dir"
echo "  backup tarball           : $BACKUP.tar.gz"
echo
printf 'All Claude Code sessions closed? Proceed? [y/N] '
read -r ans
case "$ans" in y|Y) ;; *) echo "Aborted."; exit 1 ;; esac

# --- 0. refresh dotfiles so CLAUDE.md / settings.json are the latest synced copy ---
( cd "$HOME/dotfiles" && git pull --rebase --autostash ) \
  || echo "warn: 'git pull' in ~/dotfiles failed — ensure it is up to date."

# --- 1. full backup ----------------------------------------------------------
echo "==> Backing up to $BACKUP.tar.gz ..."
TARGETS=()
for d in .claude .claude-primary; do [ -e "$HOME/$d" ] && TARGETS+=("$d"); done
[ -n "$CORP" ]     && TARGETS+=("$(basename "$CORP")")
[ -n "$PERSONAL" ] && TARGETS+=("$(basename "$PERSONAL")")
[ -f "$HOME/.claude.json" ] && TARGETS+=(".claude.json")
tar czf "$BACKUP.tar.gz" -C "$HOME" "${TARGETS[@]}"
cp -p "$HOME/.zshrc" "$HOME/.zshrc.pre-consolidate-$TS" 2>/dev/null || true

# --- 2. merge conversations + history into ~/.claude -------------------------
echo "==> Merging conversations + history into ~/.claude ..."
mkdir -p "$HOME/.claude"
merge_in() {
  local src="$1"; [ -d "$src" ] || return 0
  for sub in projects todos; do
    [ -d "$src/$sub" ] && { mkdir -p "$HOME/.claude/$sub"; rsync -a "$src/$sub/" "$HOME/.claude/$sub/"; }
  done
  for f in "$src"/history*; do [ -e "$f" ] && rsync -a "$f" "$HOME/.claude/"; done
}
merge_in "$CORP"
merge_in "$PERSONAL"

# --- 3. adopt corp login/state as the single ~/.claude.json ------------------
if [ -n "$CORP" ] && [ -f "$CORP/.claude.json" ]; then
  echo "==> Adopting corp .claude.json -> ~/.claude.json ..."
  cp -p "$CORP/.claude.json" "$HOME/.claude.json"
fi

# --- 4. link synced config into ~/.claude (replaces the old real settings.json) ---
echo "==> Linking synced config into ~/.claude ..."
for item in settings.json CLAUDE.md skills rules agents commands; do
  [ -e "$DOT/$item" ] || continue
  rm -rf "$HOME/.claude/$item"
  ln -s "$DOT/$item" "$HOME/.claude/$item"
done
chmod +x "$DOT/statusline-command.sh" 2>/dev/null || true

# --- 5. drop RTK (local files; @RTK.md import already removed from synced CLAUDE.md) ---
echo "==> Removing local RTK files ..."
rm -f "$HOME/.claude/RTK.md"
rm -f "$HOME/.claude/hooks/rtk-rewrite.sh" "$HOME/.claude/hooks/.rtk-hook.sha256"
rmdir "$HOME/.claude/hooks" 2>/dev/null || true

# --- 6. drop the multi-account shell aliases --------------------------------
echo "==> Removing multi-account aliases from ~/.zshrc ..."
if [ -f "$HOME/.zshrc" ]; then
  sed -i.bak-"$TS" \
    -e '/^alias claude=.*CLAUDE_CONFIG_DIR=/d' \
    -e '/^alias claudeMG=.*CLAUDE_CONFIG_DIR=/d' \
    "$HOME/.zshrc"
fi
# fallback: if `claude` no longer resolves (i.e. ~/.local/bin not on PATH), add a plain alias
if ! command -v claude >/dev/null 2>&1 \
   && [ -x "$HOME/.local/bin/claude" ] \
   && ! grep -q "^alias claude=" "$HOME/.zshrc" 2>/dev/null; then
  echo "alias claude='~/.local/bin/claude'" >> "$HOME/.zshrc"
  echo "   (added fallback alias: ~/.local/bin is not on PATH)"
fi

# --- 7. delete the now-merged account dirs ----------------------------------
echo "==> Removing old account dirs ..."
[ -n "$CORP" ]     && rm -rf "$CORP"
[ -n "$PERSONAL" ] && rm -rf "$PERSONAL"
rm -rf "$HOME/.claude-primary"

echo
echo "✅ Done — single config dir is now ~/.claude"
echo "   Backup : $BACKUP.tar.gz   (zshrc: ~/.zshrc.pre-consolidate-$TS)"
echo "   Next   :"
echo "     1) open a NEW terminal  (aliases are gone; 'claude' uses ~/.claude)"
echo "     2) run:  claude         # if not logged into corp, run /login once"
echo "     3) plugins reinstall automatically on first launch"
