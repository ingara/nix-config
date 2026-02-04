#!/usr/bin/env bash

# Modern yabai status indicator
yabai=(
  update_freq=0
  display=active
  script="$PLUGIN_DIR/yabai.sh"
  padding_left=$ITEM_SPACING
  
  icon="􀢊"
  icon.font="$ICON_FONT:Semibold:15.0"
  icon.color=$COLOR_ERROR
  
  label="Yabai Error"
  label.font="$FONT_FAMILY:Medium:13.0"
  label.color=$COLOR_ERROR
)

sketchybar --add item yabai left \
  --set yabai "${yabai[@]}" \
  --subscribe yabai skhd_space_type_changed skhd_window_type_changed yabai_window_focused yabai_loaded \
              aerospace_workspace_change aerospace_loaded aerospace_monitor_changed