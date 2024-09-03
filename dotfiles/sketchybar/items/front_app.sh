#!/usr/bin/env bash

APP_FONT="SF Pro"

prefs=(
  update_freq=10
  padding_left=15
  icon.drawing=on
  icon="􀆊"
  icon.padding_right=5
  label.font="$APP_FONT:Bold:14.0"
  script="$PLUGIN_DIR/front_app.sh"
)

sketchybar \
  --add item front_app left \
  --set front_app "${prefs[@]}" \
  --subscribe front_app front_app_switched
