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
    trap "rm -f $SCREEN_FILE" EXIT
    zellij action dump-screen "$SCREEN_FILE"
fi

# Extract URLs, deduplicate, and let user pick
if command -v rg &> /dev/null; then
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

# Use fzf to pick URL
SELECTED=$(echo "$URLS" | fzf --prompt='Open URL: ' --height=40% --reverse)

if [ -n "$SELECTED" ]; then
    # Open URL in default browser
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open "$SELECTED"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        xdg-open "$SELECTED"
    fi
fi
