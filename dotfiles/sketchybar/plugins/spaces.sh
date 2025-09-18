#!/usr/bin/env bash

source "$HOME/.config/sketchybar/colors.sh"

# Source icon_map.sh to get the __icon_map function
source /Users/ingar/.nix-profile/bin/icon_map.sh 2>/dev/null

# Get apps in current space using yabai
get_space_apps() {
  local space_id="$1"
  yabai -m query --windows --space "$space_id" | jq -r '.[].app' | sort | uniq | head -3
}

# Update space indicator
update_space() {
  local space_num="${NAME#*.}"
  local apps=$(get_space_apps "$space_num")
  local app_icons=""
  local app_count=0
  
  # Build app icons string (max 3 apps)
  while IFS= read -r app && [ $app_count -lt 3 ]; do
    if [ -n "$app" ]; then
      __icon_map "$app"
      if [ -n "$icon_result" ]; then
        app_icons="$app_icons$icon_result"
      else
        app_icons="$app_icons•"  # Simple fallback
      fi
      app_count=$((app_count + 1))
    fi
  done <<< "$apps"
  
  # Set the space appearance
  if [ "$SELECTED" = "true" ]; then
    # Active space - pink with number
    sketchybar --set "$NAME" \
      icon="$space_num" \
      icon.color="$COLOR_PINK" \
      label="$app_icons" \
      label.color="$COLOR_PINK"
  else
    # Inactive space - gray number, small app icons
    if [ -n "$app_icons" ]; then
      sketchybar --set "$NAME" \
        icon="$space_num" \
        icon.color="$COLOR_ICON_SECONDARY" \
        label="$app_icons" \
        label.color="$COLOR_ICON_SECONDARY"
    else
      sketchybar --set "$NAME" \
        icon="$space_num" \
        icon.color="$COLOR_ICON_SECONDARY" \
        label="" \
        label.color="$COLOR_ICON_SECONDARY"
    fi
  fi
}

case "$SENDER" in
  "space_change"|"window_focus"|"forced") update_space ;;
  *) update_space ;;
esac