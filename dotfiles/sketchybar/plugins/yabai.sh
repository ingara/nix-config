#!/usr/bin/env bash

# Dispatch to appropriate WM status plugin
if pgrep -x "AeroSpace" > /dev/null 2>&1; then
  source "$HOME/.config/sketchybar/plugins/aerospace_status.sh"
elif pgrep -x "yabai" > /dev/null 2>&1; then
  source "$HOME/.config/sketchybar/plugins/yabai_status.sh"
fi
