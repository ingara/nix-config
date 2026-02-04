#!/usr/bin/env bash

# Detect WM and source appropriate config
if pgrep -x "AeroSpace" > /dev/null 2>&1; then
  source "$ITEM_DIR/spaces_aerospace.sh"
elif pgrep -x "yabai" > /dev/null 2>&1; then
  source "$ITEM_DIR/spaces_yabai.sh"
fi
