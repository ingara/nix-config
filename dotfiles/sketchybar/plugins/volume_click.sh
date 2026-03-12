#!/bin/sh

# Debug logging
echo "$(date): volume_click.sh executed" >> /tmp/volume_click.log

# Set NAME if not set (default to volume)
NAME="${NAME:-volume}"

source "$HOME/.config/sketchybar/env.sh"

# Check if SwitchAudioSource is available
SWITCH_AUDIO_SOURCE="$(command -v SwitchAudioSource)"
[ -x "$SWITCH_AUDIO_SOURCE" ] || exit 0

POPUP_OFF='sketchybar --set volume popup.drawing=off'

toggle_devices() {
  # Remove all existing device items first
  sketchybar --remove '/volume\.device\..*/' 2>/dev/null

  # Build args array for atomic update
  args=(
    --set "$NAME" popup.drawing=toggle
  )

  COUNTER=0
  CURRENT="$($SWITCH_AUDIO_SOURCE -c -t output)"

  # Loop through all output devices
  while IFS= read -r device; do
    [ -z "$device" ] && continue

    # Determine icon based on device type
    case "$device" in
      *"AirPods"*|*"Headphones"*|*"Beats"*)
        device_icon="􀟰"
        ;;
      *"Speaker"*|*"MacBook"*)
        device_icon="􀟯"
        ;;
      *"Display"*|*"Monitor"*|*"TV"*)
        device_icon="􀡴"
        ;;
      *)
        device_icon="􀝎"
        ;;
    esac

    # Set color based on whether this is the current device
    if [ "$device" = "$CURRENT" ]; then
      label_color="$COLOR_ACCENT"
      icon_color="$COLOR_ACCENT"
    else
      label_color="$COLOR_LABEL"
      icon_color="$COLOR_ICON_SECONDARY"
    fi

    # Add device item to args
    args+=(
      --add item volume.device.$COUNTER popup."$NAME"
      --set volume.device.$COUNTER
        icon="$device_icon"
        icon.color="$icon_color"
        label="$device"
        label.color="$label_color"
        click_script="$SWITCH_AUDIO_SOURCE -s \"$device\" && sketchybar --trigger volume_change; $POPUP_OFF"
    )

    COUNTER=$((COUNTER + 1))
  done <<EOF
$($SWITCH_AUDIO_SOURCE -a -t output)
EOF

  # Execute all commands atomically
  sketchybar -m "${args[@]}" > /dev/null
}

toggle_devices
