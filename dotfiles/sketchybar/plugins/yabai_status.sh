#!/usr/bin/env bash

source "$HOME/.config/sketchybar/env.sh"

ICON_BSP=􀻤
ICON_STACK=􀏭
ICON_FLOAT=􀢌

FLOAT_LAYOUT_COLOR=$COLOR_BLUE
BSP_LAYOUT_COLOR=$COLOR_YELLOW
STACK_LAYOUT_COLOR=$COLOR_MAGENTA

update_status() {
  icon="$ICON_STACK" label='ERROR' color="$COLOR_RED"
  window_info="$(yabai -m query --windows --window 2>/dev/null)"

  if [ -z "$window_info" ]; then
    sketchybar --set "$NAME" icon="$ICON_STACK" label="—" icon.color="$STACK_LAYOUT_COLOR" label.color="$STACK_LAYOUT_COLOR"
    return
  fi

  if [[ "$(echo "$window_info" | jq -r '."is-floating"')" == 'true' ]]; then
    icon="$ICON_FLOAT" label='Float' color="$FLOAT_LAYOUT_COLOR"
  else
    space_type="$(yabai -m query --spaces --space | jq -r '.type')"
    if [[ "$space_type" == 'float' ]]; then
      icon="$ICON_FLOAT" label='FLOAT' color="$FLOAT_LAYOUT_COLOR"
    else
      stack_index="$(echo "$window_info" | jq '.["stack-index"]')"
      if [[ "$stack_index" == 0 ]]; then
        if [[ "$space_type" == 'bsp' ]]; then
          icon="$ICON_BSP" label='BSP' color="$BSP_LAYOUT_COLOR"
        elif [[ "$space_type" == 'stack' ]]; then
          icon="$ICON_STACK" label='STACK' color="$STACK_LAYOUT_COLOR"
        fi
      else
        last_stack_index="$(yabai -m query --windows --window stack.last | jq '.["stack-index"]')"
        icon="$ICON_STACK"
        label="$(printf "[%s/%s]" "$stack_index" "$last_stack_index")"
        color="$STACK_LAYOUT_COLOR"
      fi
    fi
  fi

  sketchybar --set "$NAME" icon="$icon" label="$label" icon.color="$color" label.color="$color"
}

update_status
