#!/usr/bin/env bash

source "$HOME/.config/sketchybar/env.sh"

# Driven purely by sketchybar's built-in front_app_switched event (a macOS
# NSWorkspace signal): it fires on subscribe and on every app switch, with the
# app's display name in $INFO. That's WM-agnostic — no yabai/WM query needed,
# and sketchybar fires it on load so the initial label is covered too.
[ "$SENDER" = "front_app_switched" ] && [ -n "$INFO" ] || exit 0

__icon_map "$INFO"
sketchybar --set "$NAME" icon="${icon_result:-􀆊}" label="$INFO"
