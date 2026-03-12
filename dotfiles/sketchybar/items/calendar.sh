#!/usr/bin/env bash

prefs=(
  update_freq=10
  padding_left=$ITEM_SPACING
  icon="􀉉"
  icon.font="$ICON_FONT:Semibold:14.0"
  icon.color=$COLOR_ACCENT
  icon.padding_right=$ITEM_PADDING
  label.font="$FONT_FAMILY:Medium:13.0"
  label.color=$COLOR_LABEL
  label.align=right
  script="$PLUGIN_DIR/calendar.sh"
)

sketchybar \
  --add item calendar right \
  --set calendar "${prefs[@]}"