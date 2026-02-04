#!/usr/bin/env bash

prefs=(
  update_freq=10
  icon=
  icon.color="$COLOR_BLUE"
  script="$PLUGIN_DIR/clock.sh"
)

sketchybar \
  --add item clock right \
  --set clock "${prefs[@]}"
# --set clock update_freq=10 icon= script="$PLUGIN_DIR/clock.sh"
