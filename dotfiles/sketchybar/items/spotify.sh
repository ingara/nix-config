#!/usr/bin/env bash

# Modern Spotify controls with consistent styling
spotify_opts=(
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
  script="$PLUGIN_DIR/spotify.sh"
  click_script="open -a 'Spotify'"
)

play_opts=(
  update_freq=5
  icon="􀊄"
  icon.font="$ICON_FONT:Semibold:14.0"
  icon.color=$COLOR_ACCENT
  label.width=0
  padding_left=$ITEM_PADDING
  padding_right=$ITEM_PADDING
  click_script="osascript -e 'tell application \"Spotify\" to playpause'"
)

next_opts=(
  update_freq=5
  icon="􀊐"
  icon.font="$ICON_FONT:Semibold:14.0"
  icon.color=$COLOR_ACCENT
  label.width=0
  padding_left=$ITEM_PADDING
  padding_right=$ITEM_SPACING
  click_script="osascript -e 'tell application \"Spotify\" to next track'"
)

sketchybar \
  --add event spotify_change "com.spotify.client.PlaybackStateChanged" \
  --add item spotify.next right \
  --set spotify.next "${next_opts[@]}" \
  --add item spotify.play right \
  --set spotify.play "${play_opts[@]}" \
  --add item spotify right \
  --set spotify "${spotify_opts[@]}" \
  --subscribe spotify spotify_change