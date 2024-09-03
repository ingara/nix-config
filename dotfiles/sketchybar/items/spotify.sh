#!/bin/sh

opts=(
  # icon="󰘳"
  # icon.font="$FONT:Black:16.0"
  # icon.color="$COLOR_GREEN"
  # padding_right=15
  # label.drawing=off
  # click_script="$POPUP_CLICK_SCRIPT"
  # popup.height=35
  update_freq=5
  label.font="SF Pro:Regular:12.0"
  label="(Spotify)"
  label.max_chars=50
  scroll_texts=off
  label.scroll_duration=1
  script="$PLUGIN_DIR/spotify.sh"
  click_script="open -a 'Spotify'"
)

play_opts=(
  update_freq=5
  icon=⏯
  label.width=0
  padding_left=0
  padding_right=0
  click_script="osascript -e 'tell application \"Spotify\" to playpause'"
)
next_opts=(
  update_freq=5
  icon=􀊐
  label.width=0
  padding_right=15
  click_script="osascript -e 'tell application \"Spotify\" to next track'"
)

sketchybar \
  --add event spotify_change "com.spotify.client.PlaybackStateChanged" \
  --add item spotify.next right \
  --set spotify.next "${next_opts[@]}" \
  --add item spotify.play right \
  --set spotify.play "${play_opts[@]}" \
  --add item spotify right \
  --set spotify "${opts[@]}" \
  --subscribe spotify spotify_change

