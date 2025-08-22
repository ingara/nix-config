#!/usr/bin/env bash

# Utility function to set rule and move existing windows
set_app_location() {
  local app="$1"
  local space="$2"
  local display="$3"
  local label="setup-$1"

  # Set the rule
  if [ -n "$display" ]; then
    yabai -m rule --add label="$label" app="$app" label="$label" space=$space display=$display
  else
    yabai -m rule --add label="$label" app="$app" space=$space
  fi

  # Move existing windows
  yabai -m query --windows | grep -o "\"app\":\"$app\".*\"id\":[0-9]*" | grep -o '[0-9]*$' | while read window_id; do
    if [ -n "$display" ]; then
      yabai -m window $window_id --space $space --display $display
    else
      yabai -m window $window_id --space $space
    fi
  done
}

clear_setup_rules() {
  echo "Clearing existing setup rules..."

  setup_rules=$(yabai -m rule --list | grep 'label=setup-' | awk '{print $2}')
  for rule in $setup_rules; do
    yabai -m rule --remove "$rule"
  done
}

setup_home() {
  echo "Applying home office setup..."

  yabai -m space 1 --layout stack
  yabai -m space 2 --layout bsp
  yabai -m space 3 --layout bsp
  yabai -m space 4 --layout bsp
  yabai -m space 5 --layout bsp

  # Ensure space 5 exists and is on secondary display
  current_spaces=$(yabai -m query --spaces --display 2 | grep -c '"index":')
  if [ $current_spaces -eq 0 ]; then
    yabai -m space --create
    yabai -m space 5 --display 2
  fi

  # Set app locations: Samsung main (display 1) + Acer secondary (display 2)
  set_app_location "Cursor" 2 1
  set_app_location "Arc" 2 1
  set_app_location "Slack" 5 2
  set_app_location "WhatsApp" 4 1
  set_app_location "Airmail" 4 1

  osascript -e "display notification \"Home office setup loaded!\" with title \"yabai\""
}

setup_office() {
  echo "Applying office setup..."

  yabai -m space 1 --layout stack
  yabai -m space 2 --layout bsp
  yabai -m space 3 --layout bsp
  yabai -m space 4 --layout bsp
  yabai -m space 5 --layout bsp

  # Set app locations: Mac main (display 1) + LG secondary (display 2)
  set_app_location "Cursor" 5 2
  set_app_location "Arc" 5 2
  set_app_location "Slack" 3 1
  set_app_location "WhatsApp" 4 1
  set_app_location "Airmail" 4 1

  osascript -e "display notification \"Office setup loaded!\" with title \"yabai\""
}

setup_mobile() {
  echo "Applying mobile setup..."

  yabai -m space 1 --layout stack
  yabai -m space 2 --layout stack
  yabai -m space 3 --layout stack
  yabai -m space 4 --layout stack

  # Set app locations: Mac only (no display parameter = display 1)
  set_app_location "Cursor" 2
  set_app_location "Arc" 2
  set_app_location "Slack" 3
  set_app_location "WhatsApp" 4
  set_app_location "Airmail" 4

  osascript -e "display notification \"Laptop setup loaded!\" with title \"yabai\""
}

clear_setup_rules

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
