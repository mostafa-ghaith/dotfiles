#!/usr/bin/env bash
#
# claude-backup-conversations.sh
# ------------------------------
# Safety-net backup of every Claude Code config dir on this machine BEFORE
# consolidating the multi-account (CLAUDE_CONFIG_DIR) setup into a single ~/.claude.
#
# It is READ-ONLY on the source dirs. It writes two independent backups:
#   1. A browsable snapshot tree under ~/claude-backups/conversations-<machine>-<date>/
#      (one subdir per source: default-claude/, account1/, account2/) holding the
#      conversation state you'd actually want to recover (projects/, sessions/,
#      todos/, shell-snapshots/, history.jsonl, .claude.json).
#   2. A full compressed tarball ~/claude-backups/full-<machine>-<timestamp>.tar.gz
#      of the entire config dirs + ~/.claude.json + ~/.zshrc (belt-and-suspenders).
#
# Re-runnable: every run is timestamped, so it never clobbers a previous backup.
#
# Usage:  bash ~/dotfiles/claude-backup-conversations.sh
#
set -euo pipefail

# --- identity -------------------------------------------------------------
TS="$(date +%Y%m%d-%H%M%S)"
DATE="$(date +%Y-%m-%d)"
MACHINE="$(scutil --get ComputerName 2>/dev/null || hostname -s)"
MACHINE="$(printf '%s' "$MACHINE" | tr ' ' '-' | tr -cd 'A-Za-z0-9._-')"   # sanitize
[ -n "$MACHINE" ] || MACHINE="mac"

BACKUP_ROOT="$HOME/claude-backups"
SNAP_DIR="$BACKUP_ROOT/conversations-${MACHINE}-${DATE}"
TARBALL="$BACKUP_ROOT/full-${MACHINE}-${TS}.tar.gz"
mkdir -p "$SNAP_DIR"

# Source config dir -> label in the snapshot tree
declare -a SRC_DIRS=("$HOME/.claude"            "$HOME/.claude-account1" "$HOME/.claude-account2")
declare -a SRC_LBLS=("default-claude"           "account1"               "account2")

copy_if_exists() {  # $1 src  $2 dst
  if [ -e "$1" ]; then
    if command -v rsync >/dev/null 2>&1; then
      rsync -a "$1" "$2"
    else
      cp -R "$1" "$2"
    fi
  fi
}

echo "=== Claude Code conversation backup ==="
echo "machine : $MACHINE"
echo "snapshot: $SNAP_DIR"
echo "tarball : $TARBALL"
echo

# --- 1. browsable per-account snapshot of conversation state --------------
TAR_INPUTS=()
for i in "${!SRC_DIRS[@]}"; do
  src="${SRC_DIRS[$i]}"; lbl="${SRC_LBLS[$i]}"
  [ -d "$src" ] || { echo "skip  $lbl  ($src not present)"; continue; }
  dst="$SNAP_DIR/$lbl"; mkdir -p "$dst"
  echo "snap  $lbl  <- $src"
  for item in projects sessions todos shell-snapshots history.jsonl; do
    copy_if_exists "$src/$item" "$dst/"
  done
  # login/account metadata: account dirs keep .claude.json inside; the default
  # account's lives at ~/.claude.json (handled below).
  copy_if_exists "$src/.claude.json" "$dst/"
  # quick per-source manifest
  {
    echo "source: $src"
    echo "captured: $TS"
    if [ -f "$src/.claude.json" ]; then
      /usr/bin/python3 - "$src/.claude.json" <<'PY' 2>/dev/null || true
import json,sys
d=json.load(open(sys.argv[1])); a=d.get("oauthAccount",{})
print("login:", a.get("emailAddress","(none)"), "|", a.get("organizationName",""))
PY
    fi
    echo "transcripts: $(find "$src/projects" -name '*.jsonl' 2>/dev/null | wc -l | tr -d ' ')"
    echo "projects_size: $(du -sh "$src/projects" 2>/dev/null | cut -f1)"
  } > "$dst/MANIFEST.txt"
  TAR_INPUTS+=("$src")
done

# default account login lives in the home dir, not inside ~/.claude
copy_if_exists "$HOME/.claude.json" "$SNAP_DIR/default-claude/home-.claude.json" || true

echo

# --- 2. full tarball (everything, for true disaster recovery) -------------
echo "Creating full tarball (this can take a moment)..."
EXTRA=()
[ -f "$HOME/.claude.json" ]        && EXTRA+=("$HOME/.claude.json")
[ -f "$HOME/.claude.json.backup" ] && EXTRA+=("$HOME/.claude.json.backup")
[ -f "$HOME/.zshrc" ]              && EXTRA+=("$HOME/.zshrc")
# -C "$HOME" + relative paths so the archive restores cleanly under any home
REL_INPUTS=()
for p in "${TAR_INPUTS[@]}" "${EXTRA[@]}"; do REL_INPUTS+=("${p#$HOME/}"); done
tar czf "$TARBALL" -C "$HOME" "${REL_INPUTS[@]}"

echo
echo "=== Summary ==="
echo "Browsable snapshot : $SNAP_DIR"
du -sh "$SNAP_DIR" 2>/dev/null | cut -f1 | sed 's/^/  size: /'
echo "Full tarball       : $TARBALL"
ls -lh "$TARBALL" | awk '{print "  size: "$5}'
shasum -a 256 "$TARBALL" | awk '{print "  sha256: "$1}'
echo
echo "Total transcripts captured (all sources):"
find "$SNAP_DIR" -name '*.jsonl' 2>/dev/null | wc -l | tr -d ' ' | sed 's/^/  /'
echo
echo "Done. Verify the snapshot before running any destructive consolidation step."
