#!/usr/bin/env bash

source "$HOME/.config/sketchybar/env.sh"

update() {
  PLAYING=1
  TRACK=""
  ARTIST=""
  
  # Check if Spotify is running
  if ! pgrep -f "Spotify" > /dev/null 2>&1; then
    sketchybar --set "$NAME" label="Spotify Not Running" drawing=off
    sketchybar --set spotify.play drawing=off
    return
  fi
  
  # Get playback state and track info
  if [ -z "$INFO" ]; then
    if [ "$(osascript -e 'tell application "Spotify" to player state' 2>/dev/null)" == 'playing' ]; then
      PLAYING=0
    fi
    TRACK="$(osascript -e 'tell application "Spotify" to name of current track' 2>/dev/null)"
    ARTIST="$(osascript -e 'tell application "Spotify" to artist of current track' 2>/dev/null)"
  elif [ "$(echo "$INFO" | jq -r '.["Player State"]' 2>/dev/null)" = "Playing" ]; then
    PLAYING=0
    TRACK="$(echo "$INFO" | jq -r .Name 2>/dev/null)"
    ARTIST="$(echo "$INFO" | jq -r .Artist 2>/dev/null)"
  fi

  # Update main Spotify item
  if [ $PLAYING -eq 0 ] && [ -n "$TRACK" ]; then
    if [ -n "$ARTIST" ]; then
      sketchybar --set "$NAME" label="$ARTIST – $TRACK" icon="􀑪" icon.color="$COLOR_SUCCESS" drawing=on
    else
      sketchybar --set "$NAME" label="$TRACK" icon="􀑪" icon.color="$COLOR_SUCCESS" drawing=on
    fi
    sketchybar --set spotify.play icon="􀊆" icon.color="$COLOR_ACCENT" drawing=on
    sketchybar --set spotify.next drawing=on
  else
    sketchybar --set "$NAME" label="Not Playing" icon="􀑪" icon.color="$COLOR_ICON_SECONDARY" drawing=on
    sketchybar --set spotify.play icon="􀊄" icon.color="$COLOR_ICON_SECONDARY" drawing=on
    sketchybar --set spotify.next drawing=off
  fi
}

handle_click() {
  case "$NAME" in
    "spotify") osascript -e 'tell application "Spotify" to playpause' ;;
    "spotify.play") osascript -e 'tell application "Spotify" to playpause' ;;
    "spotify.next") osascript -e 'tell application "Spotify" to next track' ;;
  esac
}

case "$SENDER" in
  "mouse.clicked") handle_click ;;
  "forced") exit 0 ;;
  *) update ;;
esac