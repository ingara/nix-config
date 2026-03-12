#!/bin/sh

source "$HOME/.config/sketchybar/env.sh"

PERCENTAGE="$(pmset -g batt | rg -o "\d+%" | cut -d% -f1)"
CHARGING="$(pmset -g batt | rg 'AC Power')"

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

if [[ "$CHARGING" != "" ]]; then
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
