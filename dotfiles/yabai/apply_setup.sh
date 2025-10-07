#!/usr/bin/env bash
# Apply yabai workspace setup based on display configuration
# Usage: apply_setup.sh {home|office|mobile|auto}
#
# Setups:
#   home   - Home office: External monitor (display 2) as main, MacBook as secondary
#   office - Office: External monitor (display 2) as main, MacBook as secondary
#   mobile - Laptop only: Single display, all stack layout
#   auto   - Auto-detect based on connected displays

# Ensure spaces are labeled before proceeding
~/.config/yabai/label_spaces.sh > /dev/null 2>&1

# Utility function to move all windows of an app to a space
# The space parameter implicitly handles display relocation
move_app_windows() {
  local app="$1"
  local space="$2"

  yabai -m query --windows | jq -r --arg app "$app" '.[] | select(.app == $app) | .id' | while read -r window_id; do
    yabai -m window "$window_id" --space "$space" 2>/dev/null
  done
}

# Move Arc windows individually: first to dev, second to specified space
move_arc_windows() {
  local second_arc_space="${1:-work}"  # Where to put second Arc (default: work)

  # Get Arc windows sorted by ID (creation order)
  arc_windows=$(yabai -m query --windows | jq -r '[.[] | select(.app == "Arc")] | sort_by(.id) | .[].id')

  local index=0
  for window_id in $arc_windows; do
    if [ $index -eq 0 ]; then
      # First Arc window -> dev space
      yabai -m window "$window_id" --space dev 2>/dev/null
    else
      # Second+ Arc windows -> specified space
      yabai -m window "$window_id" --space "$second_arc_space" 2>/dev/null
    fi
    index=$((index + 1))
  done
}

# Arrange dev space with BSP layout: Arc west, Cursor windows stacked east
arrange_dev_bsp() {
  echo "Arranging dev space in BSP layout..."

  # Step 1: Get window IDs
  arc_id=$(yabai -m query --windows | jq -r '[.[] | select(.app == "Arc")] | sort_by(.id) | .[0].id // empty')
  readarray -t cursor_ids < <(yabai -m query --windows | jq -r '[.[] | select(.app == "Cursor")] | sort_by(.id) | .[].id')

  # Exit if no windows found
  if [ -z "$arc_id" ] || [ ${#cursor_ids[@]} -eq 0 ]; then
    echo "  No Arc or Cursor windows found, skipping BSP arrangement"
    return
  fi

  # Step 2: Set dev space to BSP
  yabai -m space dev --layout bsp

  # Step 3: Ensure Arc and Cursors are in dev space
  yabai -m window "$arc_id" --space dev 2>/dev/null
  for cursor_id in "${cursor_ids[@]}"; do
    yabai -m window "$cursor_id" --space dev 2>/dev/null
  done

  echo "  Positioning Arc on the left..."
  # Step 4: Position Arc window on the left
  yabai -m window --focus "$arc_id" 2>/dev/null
  yabai -m window --swap first 2>/dev/null

  echo "  Creating stack on the right..."
  # Step 5: Position first Cursor to the right of Arc
  yabai -m window --focus "${cursor_ids[0]}" 2>/dev/null
  yabai -m window --warp east 2>/dev/null

  # Step 6: Add remaining Cursors to the stack using insertion point
  for ((i=1; i<${#cursor_ids[@]}; i++)); do
    echo "    Adding Cursor ${cursor_ids[$i]} to stack..."
    # Set insertion point on first cursor before each warp
    yabai -m window --focus "${cursor_ids[0]}" 2>/dev/null
    yabai -m window --insert stack 2>/dev/null
    # Warp the next cursor to the insertion point
    yabai -m window "${cursor_ids[$i]}" --warp "${cursor_ids[0]}" 2>/dev/null
  done

  echo "  ✓ BSP arrangement complete: Arc (west) | Cursor stack (east)"
}

setup_home() {
  echo "Applying home office setup (clamshell mode, both external monitors)..."

  # Ensure space 5 exists for secondary display
  if ! yabai -m query --spaces | jq -e '.[4]' > /dev/null 2>&1; then
    yabai -m space --create
  fi

  # Assign spaces to displays
  # Display 2 (main monitor): dev, terminal, social, work
  # Display 1 (secondary monitor): other
  yabai -m space other --display 1 2>/dev/null

  # Space layouts
  yabai -m space dev --layout bsp
  yabai -m space terminal --layout stack
  yabai -m space social --layout stack
  yabai -m space work --layout stack
  yabai -m space other --layout bsp

  # Move windows to correct spaces (spaces auto-follow their assigned displays)
  move_app_windows "Cursor" dev
  move_arc_windows other  # First Arc to dev, second Arc to other
  move_app_windows "Ghostty" terminal
  move_app_windows "WhatsApp" social
  move_app_windows "Messages" social
  move_app_windows "Airmail" work
  move_app_windows "Notion" work
  move_app_windows "Notion Calendar" work
  move_app_windows "Slack" other

  # Arrange dev space in BSP
  arrange_dev_bsp

  osascript -e "display notification \"Home office setup loaded!\" with title \"yabai\""
}

setup_office() {
  echo "Applying office setup (external monitor as main)..."

  # Ensure space 5 exists for secondary display
  if ! yabai -m query --spaces | jq -e '.[4]' > /dev/null 2>&1; then
    yabai -m space --create
  fi

  # Assign spaces to displays
  # Display 2 (external monitor - main): dev, terminal, work
  # Display 1 (MacBook - secondary): social, other
  yabai -m space social --display 1 2>/dev/null
  yabai -m space other --display 1 2>/dev/null

  # Space layouts
  yabai -m space dev --layout bsp
  yabai -m space terminal --layout stack
  yabai -m space social --layout stack
  yabai -m space work --layout stack
  yabai -m space other --layout stack

  # Move windows to correct spaces (spaces auto-follow their assigned displays)
  move_app_windows "Cursor" dev
  move_arc_windows work  # First Arc to dev, second Arc to work
  move_app_windows "Ghostty" terminal
  move_app_windows "Airmail" work
  move_app_windows "Notion" work
  move_app_windows "Notion Calendar" work
  move_app_windows "Slack" social
  move_app_windows "WhatsApp" social
  move_app_windows "Messages" social

  # Arrange dev space in BSP
  arrange_dev_bsp

  osascript -e "display notification \"Office setup loaded!\" with title \"yabai\""
}

setup_mobile() {
  echo "Applying mobile setup (laptop only)..."

  # All stack layout for 13" screen
  yabai -m space dev --layout stack
  yabai -m space terminal --layout stack
  yabai -m space social --layout stack
  yabai -m space work --layout stack

  # Move windows to correct spaces (single display)
  move_app_windows "Cursor" dev
  move_arc_windows work  # First Arc to dev, second Arc to work
  move_app_windows "Ghostty" terminal
  move_app_windows "Slack" social
  move_app_windows "WhatsApp" social
  move_app_windows "Messages" social
  move_app_windows "Airmail" work
  move_app_windows "Notion" work
  move_app_windows "Notion Calendar" work

  osascript -e "display notification \"Laptop setup loaded!\" with title \"yabai\""
}

# Main execution
case "${1:-auto}" in
"home")
  setup_home
  ;;
"office")
  setup_office
  ;;
"mobile")
  setup_mobile
  ;;
"auto")
  setup=$(~/.config/yabai/detect_setup.sh)
  echo "Auto-detected setup: $setup"
  case $setup in
  "home") setup_home ;;
  "office") setup_office ;;
  "mobile") setup_mobile ;;
  *) echo "Unknown setup: $setup" ;;
  esac
  ;;
*)
  echo "Usage: $0 {home|office|mobile|auto}"
  exit 1
  ;;
esac
