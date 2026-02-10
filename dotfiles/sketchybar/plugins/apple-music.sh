#!/usr/bin/env bash

source "$HOME/.config/sketchybar/env.sh"

update() {
  PLAYING=1
  TRACK=""
  ARTIST=""

  # Check if Music is running
  if ! pgrep -f "Music" > /dev/null 2>&1; then
    sketchybar --set "$NAME" label="Music Not Running" drawing=off
    sketchybar --set apple-music.play drawing=off
    return
  fi

  # Get playback state and track info via AppleScript
  if [ "$(osascript -e 'tell application "Music" to player state' 2>/dev/null)" == 'playing' ]; then
    PLAYING=0
  fi
  TRACK="$(osascript -e 'tell application "Music" to name of current track' 2>/dev/null)"
  ARTIST="$(osascript -e 'tell application "Music" to artist of current track' 2>/dev/null)"

  # Update main Music item
  if [ $PLAYING -eq 0 ] && [ -n "$TRACK" ]; then
    if [ -n "$ARTIST" ]; then
      sketchybar --set "$NAME" label="$ARTIST – $TRACK" icon="􀑪" icon.color="$COLOR_SUCCESS" drawing=on
    else
      sketchybar --set "$NAME" label="$TRACK" icon="􀑪" icon.color="$COLOR_SUCCESS" drawing=on
    fi
    sketchybar --set apple-music.play icon="􀊆" icon.color="$COLOR_ACCENT" drawing=on
    sketchybar --set apple-music.next drawing=on
  else
    sketchybar --set "$NAME" label="Not Playing" icon="􀑪" icon.color="$COLOR_ICON_SECONDARY" drawing=on
    sketchybar --set apple-music.play icon="􀊄" icon.color="$COLOR_ICON_SECONDARY" drawing=on
    sketchybar --set apple-music.next drawing=off
  fi
}

handle_click() {
  case "$NAME" in
    "apple-music") osascript -e 'tell application "Music" to playpause' ;;
    "apple-music.play") osascript -e 'tell application "Music" to playpause' ;;
    "apple-music.next") osascript -e 'tell application "Music" to next track' ;;
  esac
}

case "$SENDER" in
  "mouse.clicked") handle_click ;;
  "forced") exit 0 ;;
  *) update ;;
esac
