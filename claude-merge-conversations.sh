#!/usr/bin/env bash
#
# claude-merge-conversations.sh
# -----------------------------
# Merge the conversation state from the old per-account config dirs
# (~/.claude-account1 = corp, ~/.claude-account2 = personal) INTO the single
# keeper config dir ~/.claude, so that `claude --resume` finds every important
# conversation regardless of which account you are logged into.
#
# Conversations are plain local .jsonl files keyed by working directory; they
# resume independently of the OAuth login. This script does NOT touch logins,
# Keychain, or .claude.json — switch the active account with `/login`.
#
# SAFE + RE-RUNNABLE:
#   * READ-ONLY on the source account dirs.
#   * Uses `rsync --ignore-existing`, so it NEVER overwrites a file already in
#     ~/.claude. Session filenames are UUIDs, so this is a pure union.
#   * Run it as many times as you like; the result converges.
#
# Run the backup script first (claude-backup-conversations.sh).
#
# Usage:  bash ~/dotfiles/claude-merge-conversations.sh
#
set -euo pipefail

DEST="$HOME/.claude"
declare -a SRCS=("$HOME/.claude-account1" "$HOME/.claude-account2")
declare -a LBLS=("account1 (corp)"        "account2 (personal)")

# dirs to union-merge (missing ones are skipped silently)
MERGE_DIRS=(projects sessions shell-snapshots tasks todos file-history)

count_jsonl() { find "$1/projects" -name '*.jsonl' 2>/dev/null | wc -l | tr -d ' '; }

mkdir -p "$DEST"
echo "=== Merge old account conversations into $DEST ==="
echo "BEFORE: ~/.claude transcripts = $(count_jsonl "$DEST")"
echo

for i in "${!SRCS[@]}"; do
  src="${SRCS[$i]}"; lbl="${LBLS[$i]}"
  if [ ! -d "$src" ]; then echo "skip  $lbl  ($src not present)"; continue; fi
  echo "merge $lbl  <- $src  ($(count_jsonl "$src") transcripts)"
  for sub in "${MERGE_DIRS[@]}"; do
    if [ -d "$src/$sub" ]; then
      mkdir -p "$DEST/$sub"
      # trailing slash on src => merge CONTENTS; --ignore-existing => never clobber
      rsync -a --ignore-existing "$src/$sub/" "$DEST/$sub/"
    fi
  done
done

# --- history.jsonl: concatenate (corp first, then personal), de-duplicated ---
echo
echo "Merging history.jsonl (input-box history)..."
TMP="$(mktemp)"
[ -f "$DEST/history.jsonl" ] && cat "$DEST/history.jsonl" >> "$TMP"
for src in "${SRCS[@]}"; do
  [ -f "$src/history.jsonl" ] && cat "$src/history.jsonl" >> "$TMP"
done
if [ -s "$TMP" ]; then
  # keep first occurrence of each identical line, preserve order
  awk '!seen[$0]++' "$TMP" > "$DEST/history.jsonl"
  echo "  history lines now: $(wc -l < "$DEST/history.jsonl" | tr -d ' ')"
fi
rm -f "$TMP"

echo
echo "AFTER:  ~/.claude transcripts = $(count_jsonl "$DEST")"
echo "Project folders now in ~/.claude/projects:"
ls -1 "$DEST/projects" 2>/dev/null | sed 's/^/  /'
echo
echo "Done. Launch claude in any project and use --resume (or press the resume key)"
echo "to see the merged corp + personal conversations."
