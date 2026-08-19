#!/usr/bin/env bash

source "$HOME/.config/sketchybar/env.sh"

# Graphite icon (GitHub icon since it's a PR tool)
GRAPHITE_ICON=":git_hub:"

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
  item_names=""

  IFS='|' read -ra BADGES <<<"$badge_data"
  for badge in "${BADGES[@]}"; do
    if [ -z "$badge" ]; then
      continue
    fi

    IFS=':' read -r app value <<<"$badge"

    # Create sanitized item name
    item_name="notification.${app// /_}"
    item_names+="$item_name "
    current_items[$item_name]=1

    # Get app icon from icon_map
    __icon_map "$app"
    if [ -z "$icon_result" ]; then
      icon_result="•" # Fallback
    fi

    # Check if item already exists
    if echo "$existing_items" | grep -q "^$item_name$"; then
      # Update existing item
      if [[ $value =~ ^[0-9]+$ ]]; then
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
      if [[ $value =~ ^[0-9]+$ ]]; then
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

  # Add Graphite PR notifications
  graphite_count=$(get_graphite_pr_count)
  item_name="notification.Graphite"

  if [ "$graphite_count" -gt 0 ] 2>/dev/null; then
    current_items[$item_name]=1
    item_names+="$item_name "

    if echo "$existing_items" | grep -q "^$item_name$"; then
      # Update existing item
      sketchybar --set "$item_name" \
        icon="$GRAPHITE_ICON" \
        label="$graphite_count" \
        label.drawing=on
    else
      # Create new item
      sketchybar --add item "$item_name" right \
        --set "$item_name" \
        icon="$GRAPHITE_ICON" \
        icon.font="sketchybar-app-font:Regular:14.0" \
        icon.color="$COLOR_LABEL" \
        icon.padding_right=1 \
        label="$graphite_count" \
        label.font="SF Pro:Semibold:9.0" \
        label.color="$COLOR_LABEL" \
        label.padding_left=0 \
        label.padding_right=4 \
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

  # Update combined bracket (notifications + status items).
  # A bracket can't be edited in place, so refreshing it means remove + re-add,
  # which repaints the whole status cluster (WiFi/volume/battery). Doing that
  # every tick is a visible flicker — and the membership only changes when a
  # notification item appears/disappears (badge counts above update in place).
  # So rebuild the bracket only when its inputs actually change: the member set,
  # or the theme colors it's drawn with (so a scheme switch recolors it).
  local sig_file="${TMPDIR:-/tmp}/sketchybar_status_notifications.sig"
  local desired_sig
  desired_sig="${has_notifications}|${COLOR_ITEM_BACKGROUND}|${COLOR_BORDER}|$(printf '%s\n' $item_names | sort | tr '\n' ' ')"
  local prev_sig=""
  [ -f "$sig_file" ] && prev_sig=$(cat "$sig_file")

  if [ "$desired_sig" = "$prev_sig" ] && sketchybar --query status_notifications &>/dev/null; then
    return 0
  fi
  printf '%s' "$desired_sig" >"$sig_file"

  # Membership changed (or bracket missing): remove the old bracket and rebuild.
  sketchybar --remove status_notifications 2>/dev/null

  if [ "$has_notifications" = true ]; then
    # Create separator item if it doesn't exist
    if ! sketchybar --query separator.status &>/dev/null; then
      sketchybar --add item separator.status right \
        --set separator.status \
        icon="│" \
        icon.font="SF Pro:Regular:16.0" \
        icon.color="$COLOR_LABEL_SECONDARY" \
        icon.padding_left=2 \
        icon.padding_right=2 \
        label.drawing=off \
        background.drawing=off
    fi

    # Ensure separator is positioned between status items and notifications
    sketchybar --move separator.status before notifications.trigger

    # Create bracket with notifications + separator + status items
    sketchybar --add bracket status_notifications $item_names separator.status "Control Center,WiFi" volume battery \
      --set status_notifications \
      background.color="$COLOR_ITEM_BACKGROUND" \
      background.corner_radius=6 \
      background.height=26 \
      background.border_width=1 \
      background.border_color="$COLOR_BORDER"
  else
    # Remove separator when no notifications
    sketchybar --remove separator.status 2>/dev/null

    # Create bracket with just status items
    sketchybar --add bracket status_notifications "Control Center,WiFi" volume battery \
      --set status_notifications \
      background.color="$COLOR_ITEM_BACKGROUND" \
      background.corner_radius=6 \
      background.height=26 \
      background.border_width=1 \
      background.border_color="$COLOR_BORDER"
  fi
}

case "$SENDER" in
"forced") exit 0 ;;
*) update ;;
esac
