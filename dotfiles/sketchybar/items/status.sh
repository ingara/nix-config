#!/usr/bin/env bash

status_bracket=(
  background.height=25
  background.color="$COLOR_BACKGROUND_2"
  background.border_width=2
  background.border_color="$COLOR_BACKGROUND_3"
)

wifi_prefs=(
  # alias.color="$COLOR_RED"
  alias.scale=0.8
  icon.padding_left=0
  icon.padding_right=0
  label.width=0
  label.padding_left=0
  label.padding_right=0
)

sketchybar \
  --add item volume right \
  --set volume script="$PLUGIN_DIR/volume.sh" \
  --subscribe volume volume_change

sketchybar \
  --add item battery right \
  --set battery update_freq=120 script="$PLUGIN_DIR/battery.sh" \
  --subscribe battery system_woke power_source_change

sketchybar \
  --add alias "Control Center,WiFi" right \
  --set "Control Center,WiFi" "${wifi_prefs[@]}"

sketchybar \
  --add bracket status "Control Center,WiFi" volume battery \
  --set status "${status_bracket[@]}"
