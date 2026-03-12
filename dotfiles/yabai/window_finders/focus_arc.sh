#!/usr/bin/env bash
# Focus specific Arc window by position
# Usage: focus_arc.sh [dev|other|N]
#
# Examples:
#   focus_arc.sh dev     -> Focus first Arc window (dev window)
#   focus_arc.sh other   -> Focus second Arc window (work/other window)
#   focus_arc.sh 2       -> Focus third Arc window (0-indexed)
#
# Window Selection:
#   Arc windows are sorted by window ID (creation order)
#   - "dev" = first Arc window (lowest ID)
#   - "other" = second Arc window
#   - Number = Nth window (0-indexed)

target="${1:-dev}"

if [[ "$target" == "dev" ]]; then
  # First Arc window by ID (earliest created)
  window_id=$(yabai -m query --windows | jq -r '[.[] | select(.app == "Arc")] | sort_by(.id) | .[0].id // empty')
elif [[ "$target" == "other" ]]; then
  # Second Arc window by ID
  window_id=$(yabai -m query --windows | jq -r '[.[] | select(.app == "Arc")] | sort_by(.id) | .[1].id // empty')
elif [[ "$target" =~ ^[0-9]+$ ]]; then
  # Nth Arc window (0-indexed, sorted by creation order)
  window_id=$(yabai -m query --windows | jq -r --argjson n "$target" '[.[] | select(.app == "Arc")] | sort_by(.id) | .[$n].id // empty')
fi

if [ -n "$window_id" ]; then
  yabai -m window --focus "$window_id"
else
  echo "Arc window not found: $target" >&2
  exit 1
fi
