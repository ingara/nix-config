#!/usr/bin/env bash

source "$HOME/.config/sketchybar/env.sh"

AEROSPACE="${AEROSPACE:-aerospace}"
SKETCHYBAR="${SKETCHYBAR:-sketchybar}"

get_space_apps() {
  local workspace="$1"
  $AEROSPACE list-windows --workspace "$workspace" --format '%{app-name}' 2>/dev/null | sort | uniq | head -3
}

update_space() {
  local ws_id="${NAME#space.}"
  # Use FOCUSED_WORKSPACE env var passed from aerospace callback
  # Fall back to querying aerospace if not set (e.g., on initial load)
  local focused_ws="${FOCUSED_WORKSPACE:-$($AEROSPACE list-workspaces --focused 2>/dev/null)}"
  local is_focused=false
  [ "$ws_id" = "$focused_ws" ] && is_focused=true

  local apps=$(get_space_apps "$ws_id")
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

  if [ "$is_focused" = true ]; then
    $SKETCHYBAR --set "$NAME" \
      icon.color="$COLOR_PINK" \
      label="$app_icons" \
      label.color="$COLOR_PINK"
  else
    $SKETCHYBAR --set "$NAME" \
      icon.color="$COLOR_ICON_SECONDARY" \
      label="$app_icons" \
      label.color="$COLOR_ICON_SECONDARY"
  fi
}

update_space
