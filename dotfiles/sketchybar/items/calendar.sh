#!/usr/bin/env bash

CAL_FONT="SF Pro"

prefs=(
  update_freq=10
  padding_left=15
  icon=
  icon.font="$CAL_FONT:Bold:12.0"
  icon.padding_right=5
  label.font="$CAL_FONT:Regular:12.0"
  label.align=right
  script="$PLUGIN_DIR/calendar.sh"
)

sketchybar \
  --add item calendar right \
  --set calendar "${prefs[@]}"
