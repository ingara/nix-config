#!/usr/bin/env bash

source "$HOME/.config/sketchybar/colors.sh"
source /Users/ingar/.nix-profile/bin/icon_map.sh 2>/dev/null

update() {
  # Query all apps in Dock for badges via AppleScript
  badge_data=$(osascript << 'EOF'
set output to ""

tell application "System Events"
  tell process "Dock"
    try
      set dockApps to every UI element of list 1
      repeat with dockApp in dockApps
        try
          set appName to name of dockApp
          set badgeValue to value of attribute "AXStatusLabel" of dockApp
          if badgeValue is not missing value then
            set output to output & appName & ":" & badgeValue & "|"
          end if
        end try
      end repeat
    end try
  end tell
end tell

return output
EOF
)

  # Get list of currently existing notification items
  existing_items=$(sketchybar --query bar | jq -r '.items[]' | grep '^notification\.' || true)

  # Parse badge data and track which items should exist
  declare -A current_items
  has_notifications=false
  item_names=""

  IFS='|' read -ra BADGES <<< "$badge_data"
  for badge in "${BADGES[@]}"; do
    if [ -z "$badge" ]; then
      continue
    fi

    IFS=':' read -r app value <<< "$badge"

    # Create sanitized item name
    item_name="notification.${app// /_}"
    item_names+="$item_name "
    current_items[$item_name]=1

    # Get app icon from icon_map
    __icon_map "$app"
    if [ -z "$icon_result" ]; then
      icon_result="•"  # Fallback
    fi

    # Check if item already exists
    if echo "$existing_items" | grep -q "^$item_name$"; then
      # Update existing item
      if [[ "$value" =~ ^[0-9]+$ ]]; then
        sketchybar --set "$item_name" \
          icon="$icon_result" \
          label="$value" \
          label.drawing=on
      else
        sketchybar --set "$item_name" \
          icon="$icon_result" \
          label="" \
          label.drawing=off
      fi
    else
      # Create new item
      if [[ "$value" =~ ^[0-9]+$ ]]; then
        sketchybar --add item "$item_name" right \
          --set "$item_name" \
            icon="$icon_result" \
            icon.font="sketchybar-app-font:Regular:14.0" \
            icon.color="$COLOR_LABEL" \
            icon.padding_right=1 \
            label="$value" \
            label.font="SF Pro:Semibold:9.0" \
            label.color="$COLOR_LABEL" \
            label.padding_left=0 \
            label.padding_right=4 \
            label.y_offset=2
      else
        sketchybar --add item "$item_name" right \
          --set "$item_name" \
            icon="$icon_result" \
            icon.font="sketchybar-app-font:Regular:14.0" \
            icon.color="$COLOR_LABEL" \
            icon.padding_right=4 \
            label="" \
            label.drawing=off
      fi
    fi
    has_notifications=true
  done

  # Remove items that no longer have badges
  while IFS= read -r item; do
    if [ -n "$item" ] && [ -z "${current_items[$item]}" ]; then
      sketchybar --remove "$item"
    fi
  done <<< "$existing_items"

  # Update bracket to include all notification items
  if [ "$has_notifications" = true ]; then
    # Check if bracket exists
    if sketchybar --query notifications_bracket &>/dev/null; then
      # Bracket exists, just update it (bracket members can't be updated, so we need to recreate)
      sketchybar --remove notifications_bracket
      sketchybar --add bracket notifications_bracket $item_names \
        --set notifications_bracket \
          background.color="$COLOR_ITEM_BACKGROUND" \
          background.corner_radius=6 \
          background.height=26 \
          background.border_width=1 \
          background.border_color="$COLOR_BORDER"
    else
      # Create new bracket
      sketchybar --add bracket notifications_bracket $item_names \
        --set notifications_bracket \
          background.color="$COLOR_ITEM_BACKGROUND" \
          background.corner_radius=6 \
          background.height=26 \
          background.border_width=1 \
          background.border_color="$COLOR_BORDER"
    fi
  else
    sketchybar --remove notifications_bracket 2>/dev/null
  fi
}

case "$SENDER" in
  "forced") exit 0 ;;
  *) update ;;
esac
