#!/usr/bin/env bash
set -euo pipefail

# Check for --list flag
LIST_ONLY=false
SCREEN_FILE=""

for arg in "$@"; do
  case "$arg" in
  --list) LIST_ONLY=true ;;
  *) SCREEN_FILE="$arg" ;;
  esac
done

# If no screen file provided, dump current pane
if [ -z "$SCREEN_FILE" ]; then
  SCREEN_FILE=$(mktemp)
  trap 'rm -f "$SCREEN_FILE"' EXIT
  zellij action dump-screen "$SCREEN_FILE"
fi

# Extract URLs, deduplicate, and let user pick
if command -v rg &>/dev/null; then
  URLS=$(rg --no-line-number --no-column -o 'https?://[^\s<>"{}|\\^`\[\]]+' "$SCREEN_FILE" | sort -u || true)
else
  URLS=$(grep -oE 'https?://[^\s<>"{}|\\^`\[\]]+' "$SCREEN_FILE" | sort -u || true)
fi

if [ -z "$URLS" ]; then
  echo "No URLs found on screen"
  sleep 2
  exit 0
fi

# If --list flag, just print URLs and exit
if [ "$LIST_ONLY" = true ]; then
  echo "$URLS"
  exit 0
fi

is_ssh() { [ -n "${SSH_CONNECTION:-}${SSH_TTY:-}" ]; }

copy_url() {
  local url=$1
  if is_ssh; then
    # OSC52: ship to the local terminal's clipboard through the SSH hop.
    printf '\033]52;c;%s\a' "$(printf '%s' "$url" | base64 | tr -d '\n')" >/dev/tty
  elif [[ $OSTYPE == darwin* ]]; then
    printf '%s' "$url" | pbcopy
  elif command -v wl-copy &>/dev/null; then
    printf '%s' "$url" | wl-copy
  elif command -v xclip &>/dev/null; then
    printf '%s' "$url" | xclip -selection clipboard
  else
    echo "No clipboard tool available" >&2
    return 1
  fi
}

open_url() {
  local url=$1
  if [[ $OSTYPE == darwin* ]]; then
    open "$url"
  elif [[ $OSTYPE == linux-gnu* ]]; then
    xdg-open "$url"
  fi
}

# Enter = default action (open locally, copy over SSH); Ctrl-Y = force copy.
RESULT=$(echo "$URLS" | fzf \
  --prompt='URL (enter=open/copy, C-y=copy): ' \
  --height=40% --reverse --expect=ctrl-y)
KEY=$(printf '%s\n' "$RESULT" | head -n1)
SELECTED=$(printf '%s\n' "$RESULT" | tail -n +2)

[ -z "$SELECTED" ] && exit 0

if [ "$KEY" = "ctrl-y" ] || is_ssh; then
  copy_url "$SELECTED"
  echo "Copied: $SELECTED"
  sleep 1.5
else
  open_url "$SELECTED"
fi
