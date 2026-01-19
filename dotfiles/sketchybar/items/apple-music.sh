#!/usr/bin/env bash

# Modern Apple Music controls with consistent styling
apple_music_opts=(
  update_freq=5
  padding_left=$ITEM_SPACING
  icon="􀑪"
  icon.font="$ICON_FONT:Semibold:15.0"
  icon.color=$COLOR_SUCCESS
  icon.padding_right=$ITEM_PADDING
  label.font="$FONT_FAMILY:Medium:13.0"
  label.color=$COLOR_LABEL
  label="Not Playing"
  label.max_chars=40
  scroll_texts=off
  label.scroll_duration=2
  script="$PLUGIN_DIR/apple-music.sh"
  click_script="open -a 'Music'"
)

play_opts=(
  update_freq=5
  icon="􀊄"
  icon.font="$ICON_FONT:Semibold:14.0"
  icon.color=$COLOR_ACCENT
  label.width=0
  padding_left=$ITEM_PADDING
  padding_right=$ITEM_PADDING
  click_script="osascript -e 'tell application \"Music\" to playpause'"
)

next_opts=(
  update_freq=5
  icon="􀊐"
  icon.font="$ICON_FONT:Semibold:14.0"
  icon.color=$COLOR_ACCENT
  label.width=0
  padding_left=$ITEM_PADDING
  padding_right=$ITEM_SPACING
  click_script="osascript -e 'tell application \"Music\" to next track'"
)

sketchybar \
  --add item apple-music.next right \
  --set apple-music.next "${next_opts[@]}" \
  --add item apple-music.play right \
  --set apple-music.play "${play_opts[@]}" \
  --add item apple-music right \
  --set apple-music "${apple_music_opts[@]}"
