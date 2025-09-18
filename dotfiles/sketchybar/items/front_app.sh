#!/usr/bin/env bash

prefs=(
  update_freq=10
  padding_left=$ITEM_SPACING
  icon.drawing=on
  icon="􀆊"
  icon.font="$ICON_FONT:Semibold:15.0"
  icon.padding_right=$ITEM_PADDING
  icon.color=$COLOR_ACCENT
  label.font="$FONT_FAMILY:Medium:13.0"
  label.color=$COLOR_LABEL
  script="$PLUGIN_DIR/front_app.sh"
)

sketchybar \
  --add item front_app left \
  --set front_app "${prefs[@]}" \
  --subscribe front_app front_app_switched
