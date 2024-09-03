#!/bin/sh

# References:
# - https://gist.github.com/zfarbp/581ce7e50a1b5740b4d31f007cac87fb
# - https://github.com/NamesCode/.Dotfiles/blob/main/ext/sketchybar/plugins/spotify.sh

source "$HOME/.config/sketchybar/colors.sh"

update ()
{
  PLAYING=1
  if [ -z "$INFO" ]; then
    if [ "$(osascript -e 'tell application "Spotify" to player state')" == 'playing' ]; then
      PLAYING=0
    fi
    TRACK="$(osascript -e 'tell application "Spotify" to name of current track')"
    ARTIST="$(osascript -e 'tell application "Spotify" to artist of current track')"
    ALBUM="$(osascript -e 'tell application "Spotify" to album of current track')"
  elif [ "$(echo "$INFO" | jq -r '.["Player State"]')" = "Playing" ]; then
    PLAYING=0
    TRACK="$(echo "$INFO" | jq -r .Name)"
    ARTIST="$(echo "$INFO" | jq -r .Artist)"
    ALBUM="$(echo "$INFO" | jq -r .Album)"
  fi

  args=(
  )
  play_args=(
  )

  if [ $PLAYING -eq 0 ]; then
    if [ "$ARTIST" == "" ]; then
      args+=(label="$TRACK | $ALBUM")
      args+=(drawing=on)
    else
      args+=(label="$ARTIST – $TRACK")
      args+=(drawing=on)
    fi
    play_args+=(icon=􀊆)
  else
    play_args+=(icon=􀊄)
  fi
  sketchybar --set "$NAME" "${args[@]}"
  sketchybar --set spotify.play "${play_args[@]}"
}

handle_mouse_click() {
  case "$NAME" in
    "spotify") osascript -e 'tell application "Spotify" to playpause'
    ;;
    "spotify_next") osascript -e 'tell application "Spotify" to next track'
    ;;
    "spotify_prev") osascript -e 'tell application "Spotify" to previous track'
    ;;
    *) exit
    ;;
  esac
}

case "$SENDER" in
  "mouse.clicked") mouse_clicked
  ;;
  "forced") exit
  ;;
  *) update
  ;;
esac
