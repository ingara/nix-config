#!/usr/bin/env bash

##### Adding Mission Control Space Indicators #####
# Let's add some mission control spaces:
# https://felixkratz.github.io/SketchyBar/config/components#space----associate-mission-control-spaces-with-an-item
# to indicate active and available mission control spaces.
SPACE_ICONS=("1" "2" "3" "4" "5" "6" "7" "8" "9" "10")
for i in "${!SPACE_ICONS[@]}"; do
	sid="$(($i + 1))"
	space=(
		space="$sid"
		associated_space="$sid"
		icon="${SPACE_ICONS[i]}"
		icon.padding_left=12
		icon.padding_right=12
		icon.highlight_color=$COLOR_RED
		label.drawing=off
		click_script="yabai -m space --focus $sid"
	)
	sketchybar --add space space."$sid" left \
		--set space."$sid" "${space[@]}"
done
sketchybar --add bracket spaces '/space\..*/' \
	--set spaces background.color=$COLOR_GRAY \
	background.corner_radius=5 \
	background.height=25
