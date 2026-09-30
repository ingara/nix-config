#!/usr/bin/env bash

source "$HOME/.config/sketchybar/env.sh"

# Graphite icon (GitHub icon since it's a PR tool)
GRAPHITE_ICON=":git_hub:"
notification_layout=(
  padding_left="$((ITEM_SPACING / 2))"
  padding_right="$((ITEM_SPACING / 2))"
  icon.padding_left=0
  label.padding_left=0
  label.padding_right=0
)

get_graphite_pr_count() {
  # gh hits the network; this runs on every 5s tick, so cache the count and
  # only re-poll every ~30s. Keeps the common tick osascript-only (cheap), so
  # update() doesn't run long enough to overlap the next tick. The timestamp is
  # stored in the file ("epoch|count") rather than read via stat, since this
  # PATH may resolve stat to GNU coreutils (whose -f differs from BSD stat).
  local cache="${TMPDIR:-/tmp}/sketchybar_graphite_pr_count"
  local now ts count
  now=$(date +%s)
  if [ -f "$cache" ]; then
    IFS='|' read -r ts count <"$cache"
    if [ -n "$ts" ] && [ "$((now - ts))" -lt 30 ]; then
      echo "$count"
      return
    fi
  fi
  count=$(gh search prs --review-requested=@me --state=open -- -author:@me draft:false -review:approved 2>/dev/null | wc -l | tr -d ' ')
  printf '%s|%s' "$now" "$count" >"$cache"
  echo "$count"
}

update() {
  # Query all apps in Dock for badges via AppleScript
  badge_data=$(
    osascript <<'EOF'
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

  IFS='|' read -ra BADGES <<<"$badge_data"
  for badge in "${BADGES[@]}"; do
    if [ -z "$badge" ]; then
      continue
    fi

    IFS=':' read -r app value <<<"$badge"

    item_name="notification.${app// /_}"
    current_items[$item_name]=1

    __icon_map "$app"
    if [ -z "$icon_result" ]; then
      icon_result="•" # Fallback
    fi

    if echo "$existing_items" | grep -q "^$item_name$"; then
      if [[ $value =~ ^[0-9]+$ ]]; then
        sketchybar --set "$item_name" \
          "${notification_layout[@]}" \
          icon="$icon_result" \
          icon.padding_right="$ITEM_PADDING" \
          label="$value" \
          label.drawing=on
      else
        sketchybar --set "$item_name" \
          "${notification_layout[@]}" \
          icon="$icon_result" \
          icon.padding_right=0 \
          label="" \
          label.drawing=off
      fi
    else
      if [[ $value =~ ^[0-9]+$ ]]; then
        sketchybar --add item "$item_name" right \
          --set "$item_name" \
          "${notification_layout[@]}" \
          icon="$icon_result" \
          icon.font="sketchybar-app-font:Regular:14.0" \
          icon.color="$COLOR_LABEL" \
          icon.padding_right="$ITEM_PADDING" \
          label="$value" \
          label.font="SF Pro:Semibold:9.0" \
          label.color="$COLOR_LABEL" \
          label.y_offset=2
      else
        sketchybar --add item "$item_name" right \
          --set "$item_name" \
          "${notification_layout[@]}" \
          icon="$icon_result" \
          icon.font="sketchybar-app-font:Regular:14.0" \
          icon.color="$COLOR_LABEL" \
          icon.padding_right=0 \
          label="" \
          label.drawing=off
      fi
    fi
    has_notifications=true
  done

  # Add Graphite PR notifications
  graphite_count=$(get_graphite_pr_count)
  item_name="notification.Graphite"

  if [ "$graphite_count" -gt 0 ] 2>/dev/null; then
    current_items[$item_name]=1

    if echo "$existing_items" | grep -q "^$item_name$"; then
      sketchybar --set "$item_name" \
        "${notification_layout[@]}" \
        icon="$GRAPHITE_ICON" \
        icon.padding_right="$ITEM_PADDING" \
        label="$graphite_count" \
        label.drawing=on
    else
      sketchybar --add item "$item_name" right \
        --set "$item_name" \
        "${notification_layout[@]}" \
        icon="$GRAPHITE_ICON" \
        icon.font="sketchybar-app-font:Regular:14.0" \
        icon.color="$COLOR_LABEL" \
        icon.padding_right="$ITEM_PADDING" \
        label="$graphite_count" \
        label.font="SF Pro:Semibold:9.0" \
        label.color="$COLOR_LABEL" \
        label.y_offset=2 \
        click_script="open https://app.graphite.dev/inbox"
    fi
    has_notifications=true
  fi

  # Remove items that no longer have badges
  while IFS= read -r item; do
    if [ -n "$item" ] && [ -z "${current_items[$item]}" ]; then
      sketchybar --remove "$item"
    fi
  done <<<"$existing_items"

  if [ "$has_notifications" = true ]; then
    sketchybar --set separator.resources drawing=on
  else
    sketchybar --set separator.resources drawing=off
  fi
}

case "$SENDER" in
"forced") exit 0 ;;
*) update ;;
esac
