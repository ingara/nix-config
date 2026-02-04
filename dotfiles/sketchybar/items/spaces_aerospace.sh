#!/usr/bin/env bash

##### AeroSpace Workspace Indicators #####
# Format: "workspace_id:display_label"
WORKSPACES=("dev:[dev]" "terminal:[term]" "social:[chat]" "work:[work]" "other:[other]")

for ws in "${WORKSPACES[@]}"; do
  ws_id="${ws%%:*}"
  ws_label="${ws##*:}"
  space=(
    icon="$ws_label"
    icon.font="$FONT_FAMILY:Bold:10.0"
    icon.padding_left=$ITEM_PADDING
    icon.padding_right=2
    icon.highlight_color=$COLOR_PINK
    icon.color=$COLOR_ICON_SECONDARY
    label.font="sketchybar-app-font:Regular:10.0"
    label.padding_left=2
    label.padding_right=$ITEM_PADDING
    label.color=$COLOR_ICON_SECONDARY
    script="$PLUGIN_DIR/spaces_aerospace.sh"
    click_script="/opt/homebrew/bin/aerospace workspace $ws_id"
  )
  sketchybar --add item space."$ws_id" left \
    --set space."$ws_id" "${space[@]}" \
    --subscribe space."$ws_id" aerospace_workspace_change aerospace_loaded
done

sketchybar --add bracket spaces '/space\..*/' \
  --set spaces background.color=$COLOR_ITEM_BACKGROUND \
  background.corner_radius=6 \
  background.height=26 \
  background.border_width=1 \
  background.border_color=$COLOR_BORDER
