#!/usr/bin/env bash

# Read JSON input from stdin
input=$(cat)

# Extract data from JSON input
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
model=$(echo "$input" | jq -r '.model.display_name')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir')
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')

# Change to current directory
cd "$current_dir" 2>/dev/null || cd "$project_dir" 2>/dev/null || true

# Catppuccin Macchiato colors (dimmed for status line)
BLUE="\033[2;38;2;138;173;244m"    # blue (dimmed)
GREEN="\033[2;38;2;166;218;149m"   # green (dimmed)
YELLOW="\033[2;38;2;238;212;159m"  # yellow (dimmed)
RED="\033[2;38;2;237;135;150m"     # red (dimmed)
MAUVE="\033[2;38;2;198;160;246m"   # mauve (dimmed)
TEAL="\033[2;38;2;139;213;202m"    # teal (dimmed)
SUBTEXT="\033[2;38;2;165;173;203m" # subtext0 (dimmed)
RESET="\033[0m"

# Get directory name
dir_name=$(basename "$current_dir")

# Context window color
if [ "$ctx_pct" -ge 80 ]; then
  ctx_color="$RED"
elif [ "$ctx_pct" -ge 50 ]; then
  ctx_color="$YELLOW"
else
  ctx_color="$GREEN"
fi

# Format cost
cost_fmt=$(printf '$%.2f' "$cost")

# Check if we're in a git repository and get git info
if git rev-parse --git-dir >/dev/null 2>&1; then
  # Get branch name
  branch=$(git -c core.filemode=false -c advice.detachedHead=false symbolic-ref --short HEAD 2>/dev/null ||
    git -c core.filemode=false -c advice.detachedHead=false rev-parse --short HEAD 2>/dev/null ||
    echo 'unknown')

  # Get git status info
  git_status=""
  if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    git_status="${RED}*${RESET}" # Modified files
  fi

  # Check for untracked files
  if [ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
    git_status="${git_status}${YELLOW}?${RESET}" # Untracked files
  fi

  # Check for staged files
  if ! git diff-index --quiet --cached HEAD -- 2>/dev/null; then
    git_status="${git_status}${GREEN}+${RESET}" # Staged files
  fi

  printf "${TEAL}%s${RESET} ${MAUVE}%s${git_status}${RESET} ${SUBTEXT}•${RESET} ${BLUE}%s${RESET} ${SUBTEXT}•${RESET} ${ctx_color}ctx %s%%${RESET} ${SUBTEXT}•${RESET} ${SUBTEXT}%s${RESET}" \
    "$dir_name" "$branch" "$model" "$ctx_pct" "$cost_fmt"
else
  printf "${TEAL}%s${RESET} ${SUBTEXT}•${RESET} ${BLUE}%s${RESET} ${SUBTEXT}•${RESET} ${ctx_color}ctx %s%%${RESET} ${SUBTEXT}•${RESET} ${SUBTEXT}%s${RESET}" \
    "$dir_name" "$model" "$ctx_pct" "$cost_fmt"
fi
