#!/usr/bin/env bash
set -euo pipefail

# Check for --list flag
LIST_ONLY=false
if [[ "${1:-}" == "--list" ]]; then
    LIST_ONLY=true
fi

# Dump current zellij screen content
SCREEN_FILE=$(mktemp)
trap "rm -f $SCREEN_FILE" EXIT

zellij action dump-screen "$SCREEN_FILE"

# Extract URLs, deduplicate, and let user pick
if command -v rg &> /dev/null; then
    URLS=$(rg --no-line-number --no-column -o 'https?://[^\s<>"{}|\\^`\[\]]+' "$SCREEN_FILE" | sort -u)
else
    URLS=$(grep -oE 'https?://[^\s<>"{}|\\^`\[\]]+' "$SCREEN_FILE" | sort -u)
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
