#!/usr/bin/env bash


volume_opts=(
  icon="􀊢"
  icon.font="$ICON_FONT:Semibold:14.0"
  icon.color=$COLOR_ACCENT
  label.font="$FONT_FAMILY:Medium:12.0"
  label.color=$COLOR_LABEL
  script="$PLUGIN_DIR/volume.sh"
  click_script="sh $PLUGIN_DIR/volume_click.sh"
  popup.height=30
  popup.align=right
)

battery_opts=(
  icon="􀋨"
  icon.font="$ICON_FONT:Semibold:14.0"
  icon.color=$COLOR_SUCCESS
  label.font="$FONT_FAMILY:Medium:12.0"
  label.color=$COLOR_LABEL
  update_freq=120
  script="$PLUGIN_DIR/battery.sh"
)

wifi_opts=(
  alias.color=$COLOR_ACCENT
  alias.scale=0.9
  icon.padding_left=$ITEM_PADDING
  icon.padding_right=$ITEM_PADDING
  label.width=0
  label.padding_left=0
  label.padding_right=0
)

# Add items
sketchybar \
  --add item volume right \
  --set volume "${volume_opts[@]}" \
  --subscribe volume volume_change

sketchybar \
  --add item battery right \
  --set battery "${battery_opts[@]}" \
  --subscribe battery system_woke power_source_change

sketchybar \
  --add alias "Control Center,WiFi" right \
  --set "Control Center,WiFi" "${wifi_opts[@]}"

# Note: The combined bracket (status + notifications) is managed by notifications.sh