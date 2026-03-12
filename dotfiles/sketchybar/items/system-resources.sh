#!/usr/bin/env bash

# System resources warning indicator
# Shows when CPU >= 90% or memory >= 90%
# Hidden by default, only appears when threshold exceeded

system_resources_opts=(
  update_freq=5
  updates=on
  drawing=off
  icon="􀧓"
  icon.color=$COLOR_WARNING
  label.color=$COLOR_WARNING
  click_script="open -a 'Activity Monitor'"
  script="$PLUGIN_DIR/system-resources.sh"
)

sketchybar \
  --add item system_resources right \
  --set system_resources "${system_resources_opts[@]}"
