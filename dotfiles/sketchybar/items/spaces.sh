#!/usr/bin/env bash

##### Adding Mission Control Space Indicators #####
# Clean numbered space indicators
SPACE_ICONS=("1" "2" "3" "4" "5" "6" "7" "8" "9" "10")

for i in "${!SPACE_ICONS[@]}"; do
	sid="$(($i + 1))"
	space=(
		space="$sid"
		associated_space="$sid"
		icon="${SPACE_ICONS[i]}"
		icon.font="$FONT_FAMILY:Bold:14.0"
		icon.padding_left=$ITEM_PADDING
		icon.padding_right=$ITEM_PADDING
		icon.highlight_color=$COLOR_ACCENT
		icon.color=$COLOR_ICON_SECONDARY
		label.drawing=off
		click_script="yabai -m space --focus $sid"
	)
	sketchybar --add space space."$sid" left \
		--set space."$sid" "${space[@]}"
done

# Group spaces with modern bracket styling
sketchybar --add bracket spaces '/space\..*/' \
	--set spaces background.color=$COLOR_ITEM_BACKGROUND \
	background.corner_radius=6 \
	background.height=26 \
	background.border_width=1 \
	background.border_color=$COLOR_BORDER
