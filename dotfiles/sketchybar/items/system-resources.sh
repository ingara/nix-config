#!/usr/bin/env bash

resource_opts=(
  icon.font="$ICON_FONT:Semibold:13.0"
  "icon.color=$COLOR_BLACK4"
  icon.padding_left=0
  "icon.padding_right=$ITEM_PADDING"
  label.font="$FONT_MONO:Medium:11.0"
  "label.color=$COLOR_LABEL_SECONDARY"
  label.padding_left=0
  label.padding_right=0
  "padding_left=$((ITEM_SPACING / 2))"
  "padding_right=$((ITEM_SPACING / 2))"
  click_script="open -a 'Activity Monitor'"
)

separator_opts=(
  drawing=off
  icon="│"
  icon.font="$FONT_FAMILY:Regular:11.0"
  "icon.color=$COLOR_BORDER"
  icon.padding_left=0
  icon.padding_right=0
  label.drawing=off
  "padding_left=$((ITEM_SPACING / 2))"
  "padding_right=$((ITEM_SPACING / 2))"
)

driver_opts=(
  update_freq=10
  updates=on
  drawing=off
  icon.drawing=off
  label.drawing=off
  width=0
  script="$PLUGIN_DIR/system-resources.sh"
)

sketchybar \
  --add item system_resources.ram right \
  --set system_resources.ram "${resource_opts[@]}" icon="􀫦" \
  --add item system_resources.cpu right \
  --set system_resources.cpu "${resource_opts[@]}" icon="􀧓" \
  --add item separator.resources right \
  --set separator.resources "${separator_opts[@]}" \
  --add item system_resources right \
  --set system_resources "${driver_opts[@]}"
