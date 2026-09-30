#!/usr/bin/env bash

# Notification aggregator widget - creates items dynamically
# Add a dummy item that triggers the update script
notifications_opts=(
  update_freq=5
  updates=on
  icon.drawing=off
  label.drawing=off
  width=0
  script="ITEM_SPACING=$ITEM_SPACING ITEM_PADDING=$ITEM_PADDING $PLUGIN_DIR/notifications.sh"
)

sketchybar \
  --add item notifications.trigger right \
  --set notifications.trigger "${notifications_opts[@]}"
