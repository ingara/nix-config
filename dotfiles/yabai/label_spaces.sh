#!/usr/bin/env bash
# Label yabai spaces with semantic names
# Usage: label_windows.sh
#
# This enables space navigation by label instead of number:
#   yabai -m space --focus dev
#   yabai -m space --focus terminal
#   etc.
#
# Bound to: cmd + shift + alt - l
#
# Space Layout:
#   1 (dev)      -> Arc dev window + Cursor instances
#   2 (terminal) -> Ghostty/terminals
#   3 (social)   -> Slack, WhatsApp, Messages
#   4 (work)     -> Airmail, Notion, Fantastical, Arc work window
#   5 (other)    -> Overflow (only on multi-monitor setups)

# Label the four main spaces
yabai -m space 1 --label dev
yabai -m space 2 --label terminal
yabai -m space 3 --label social
yabai -m space 4 --label work

# Check if space 5 exists (multi-monitor setup)
if yabai -m query --spaces | jq -e '.[4]' > /dev/null 2>&1; then
  yabai -m space 5 --label other
  echo "✓ Labeled 5 spaces: dev, terminal, social, work, other"
else
  echo "✓ Labeled 4 spaces: dev, terminal, social, work"
fi
