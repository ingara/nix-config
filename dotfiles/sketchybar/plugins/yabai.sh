#!/usr/bin/env bash

source "$HOME/.config/sketchybar/colors.sh"

# -----------------------------------
# -------- Icons
# -----------------------------------
ICON_BSP=
ICON_STACK=
YABAI_FLOAT=
ICON_ERROR=
# YABAI_PARENT_ZOOM=􀥃
# YABAI_GRID=􀧍

# -----------------------------------
# -------- Colors
# -----------------------------------
ERROR_COLOR=$COLOR_RED
FLOAT_LAYOUT_COLOR=$COLOR_BLUE
BSP_LAYOUT_COLOR=$COLOR_YELLOW
STACK_LAYOUT_COLOR=$COLOR_MAGENTA

# -----------------------------------
# -------- Scripts
# -----------------------------------
function update_yabai_status() {
	# Init variables
	icon="$ICON_ERROR" label='ERROR' color="$ERROR_COLOR"
	# Get the window state
	window_info="$(yabai -m query --windows --window)"

	# CASE 1: Floating window
	if [[ "$(echo "$window_info" | jq -r '."is-floating"')" == 'true' ]]; then
		icon="$YABAI_FLOAT" label='Float' color="$FLOAT_LAYOUT_COLOR"
	else
		space_type="$(yabai -m query --spaces --space | jq -r '.type')"
		# CASE 2: Floating layout
		if [[ "$space_type" == 'float' ]]; then
			icon="$YABAI_FLOAT" label='FLOAT' color="$FLOAT_LAYOUT_COLOR"
		else
			stack_index="$(echo "$window_info" | jq '.["stack-index"]')"
			# CASE 3: No stack index => show layout type
			if [[ "$stack_index" == 0 ]]; then
				if [[ "$space_type" == 'bsp' ]]; then
					icon="$ICON_BSP" label='BSP' color="$BSP_LAYOUT_COLOR"
				elif [[ "$space_type" == 'stack' ]]; then
					icon="$ICON_STACK" label='STACK' color="$STACK_LAYOUT_COLOR"
				else
					echo "Invalid space type: $($space_type)" in $0
				fi
			else # CASE 4: Stack multiple windows
				last_stack_index="$(yabai -m query --windows --window stack.last | jq '.["stack-index"]')"
				icon="$ICON_STACK"
				label="$(printf "[%s/%s]" "$stack_index" "$last_stack_index")"
				color="$STACK_LAYOUT_COLOR"
			fi
		fi
	fi

	sketchybar --set "$NAME" icon="$icon" label="$label" icon.color="$color" label.color="$color"
}

# -----------------------------------
# -------- Trigger
# -----------------------------------
case "$SENDER" in
'forced' | 'skhd_space_type_changed' | 'skhd_window_type_changed' | 'yabai_window_focused' | 'yabai_loaded')
	update_yabai_status
	;;
*)
	echo "Invalid sender: $($SENDER)" in $0
	;;
esac
