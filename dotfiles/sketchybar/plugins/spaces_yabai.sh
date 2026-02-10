#!/usr/bin/env bash

source "$HOME/.config/sketchybar/env.sh"

get_space_apps() {
  local space_id="$1"
  yabai -m query --windows --space "$space_id" 2>/dev/null | jq -r '.[].app' | sort | uniq | head -3
}

update_space() {
  local space_num="${NAME#space.}"
  local apps=$(get_space_apps "$space_num")
  local app_icons=""
  local app_count=0

  while IFS= read -r app && [ $app_count -lt 3 ]; do
    if [ -n "$app" ]; then
      __icon_map "$app"
      if [ -n "$icon_result" ]; then
        app_icons="$app_icons$icon_result"
      else
        app_icons="$app_icons•"
      fi
      app_count=$((app_count + 1))
    fi
  done <<< "$apps"

  if [ "$SELECTED" = "true" ]; then
    sketchybar --set "$NAME" \
      icon.color="$COLOR_PINK" \
      label="$app_icons" \
      label.color="$COLOR_PINK"
  else
    sketchybar --set "$NAME" \
      icon.color="$COLOR_ICON_SECONDARY" \
      label="$app_icons" \
      label.color="$COLOR_ICON_SECONDARY"
  fi
}

update_space
