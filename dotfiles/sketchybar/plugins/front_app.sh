#!/usr/bin/env bash

# Source icon_map.sh to get the __icon_map function
source /Users/ingar/.nix-profile/bin/icon_map.sh 2>/dev/null

get_current_app() {
  yabai -m query --windows --space mouse | jq -r 'map(select(.["has-focus"] == true)) | .[0].app // empty'
}

if [ "$SENDER" = "front_app_switched" ] && [ -n "$INFO" ]; then
  current_app="$INFO"
else
  current_app=$(get_current_app)
fi

if [ -n "$current_app" ]; then
  __icon_map "$current_app"
  
  if [ -n "$icon_result" ]; then
    sketchybar --set "$NAME" icon="$icon_result" label="$current_app"
  else
    sketchybar --set "$NAME" icon="􀆊" label="$current_app"
  fi
fi
