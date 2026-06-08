#!/usr/bin/env bash
# Claude Code statusLine — styled after Oh My Zsh robbyrussell theme.
# Format: ➜  dir git:(branch) ✗   model  ctx:NN%

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
dir=$(basename "$cwd")

git_branch=""
git_dirty=""
if [ -n "$cwd" ] && git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git_branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null \
               || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  if [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
    git_dirty=1
  fi
fi

model=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

printf "\033[1;32m➜\033[0m  \033[36m%s\033[0m" "$dir"

if [ -n "$git_branch" ]; then
  printf " \033[1;34mgit:(\033[31m%s\033[1;34m)\033[0m" "$git_branch"
  [ -n "$git_dirty" ] && printf " \033[33m✗\033[0m"
fi

[ -n "$model" ] && printf "  \033[35m%s\033[0m" "$model"

if [ -n "$used_pct" ]; then
  used_int=${used_pct%%.*}
  [ -z "$used_int" ] && used_int=0
  if [ "$used_int" -ge 80 ]; then
    color="\033[31m"
  elif [ "$used_int" -ge 50 ]; then
    color="\033[33m"
  else
    color="\033[32m"
  fi
  printf "  ${color}ctx:%d%%\033[0m" "$used_int"
fi
