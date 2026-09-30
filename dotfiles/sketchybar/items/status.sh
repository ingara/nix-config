#!/usr/bin/env bash

volume_opts=(
  "padding_left=$((ITEM_SPACING / 2))"
  "padding_right=$((ITEM_SPACING / 2))"
  icon="􀊢"
  icon.font="$ICON_FONT:Semibold:14.0"
  "icon.color=$COLOR_ACCENT"
  icon.padding_left=0
  "icon.padding_right=$ITEM_PADDING"
  label.font="$FONT_FAMILY:Medium:12.0"
  "label.color=$COLOR_LABEL"
  label.padding_left=0
  label.padding_right=0
  script="$PLUGIN_DIR/volume.sh"
  click_script="sh $PLUGIN_DIR/volume_click.sh"
  popup.height=30
  popup.align=right
)

battery_opts=(
  "padding_left=$((ITEM_SPACING / 2))"
  "padding_right=$((ITEM_SPACING / 2))"
  icon="􀋨"
  icon.font="$ICON_FONT:Semibold:14.0"
  "icon.color=$COLOR_SUCCESS"
  icon.padding_left=0
  "icon.padding_right=$ITEM_PADDING"
  label.font="$FONT_FAMILY:Medium:12.0"
  "label.color=$COLOR_LABEL"
  label.padding_left=0
  label.padding_right=0
  update_freq=120
  script="$PLUGIN_DIR/battery.sh"
)

# Wi-Fi alias disabled until SketchyBar #842 ships in a release; unresolved
# aliases leak the system window list (https://github.com/FelixKratz/SketchyBar/issues/836).
# wifi_opts=(
#   "alias.color=$COLOR_ACCENT"
#   alias.scale=0.9
#   "icon.padding_left=$ITEM_PADDING"
#   "icon.padding_right=$ITEM_PADDING"
#   label.width=0
#   label.padding_left=0
#   label.padding_right=0
# )

# Add items
sketchybar \
  --add item volume right \
  --set volume "${volume_opts[@]}" \
  --subscribe volume volume_change

sketchybar \
  --add item battery right \
  --set battery "${battery_opts[@]}" \
  --subscribe battery system_woke power_source_change

# sketchybar \
#   --add alias "Control Center,WiFi" right \
#   --set "Control Center,WiFi" "${wifi_opts[@]}"
