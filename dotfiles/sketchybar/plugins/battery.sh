#!/usr/bin/env bash

source "$HOME/.config/sketchybar/env.sh"

BATTERY_STATUS="$(pmset -g batt)"
PERCENTAGE="$(printf '%s\n' "$BATTERY_STATUS" | sed -nE 's/.*[[:space:]]([0-9]+)%.*/\1/p' | head -n 1)"

if [ "$PERCENTAGE" = "" ]; then
  exit 0
fi

ICON_COLOR="$COLOR_CYAN"
case "${PERCENTAGE}" in
9[0-9] | 100)
  ICON=􀛨
  ICON_COLOR="$COLOR_GREEN"
  ;;
[6-8][0-9])
  ICON=􀺸
  ICON_COLOR="$COLOR_GREEN"
  ;;
[3-5][0-9])
  ICON=􀺶
  ICON_COLOR="$COLOR_YELLOW"
  ;;
[1-2][0-9])
  ICON=􀛩
  ICON_COLOR="$COLOR_RED"
  ;;
*)
  ICON=􀛪
  ICON_COLOR="$COLOR_RED"
  ;;
esac

if [[ $BATTERY_STATUS == *"AC Power"* ]]; then
  ICON=􀢋
fi

settings=(
  icon="$ICON"
  icon.color="$ICON_COLOR"
  label="${PERCENTAGE}%"
)

# The item invoking this script (name $NAME) will get its icon and label
# updated with the current battery status
sketchybar --set "$NAME" "${settings[@]}"
