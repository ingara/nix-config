#!/usr/bin/env bash

source "$HOME/.config/sketchybar/env.sh"

THRESHOLD=90

get_cpu_usage() {
  # Use top to get CPU usage (idle percentage)
  # Run two iterations to get accurate reading, take the second one
  local idle
  idle=$(top -l 2 -n 0 2>/dev/null | grep "CPU usage" | tail -1 | awk '{print $7}' | tr -d '%')
  if [ -n "$idle" ]; then
    # CPU usage = 100 - idle
    echo $((100 - ${idle%.*}))
  else
    echo 0
  fi
}

get_memory_usage() {
  # Use memory_pressure to get system memory free percentage
  local free_pct
  free_pct=$(memory_pressure 2>/dev/null | grep "System-wide memory free percentage" | awk '{print $5}' | tr -d '%')
  if [ -n "$free_pct" ]; then
    # Memory usage = 100 - free percentage
    echo $((100 - free_pct))
  else
    echo 0
  fi
}

update() {
  local cpu_usage mem_usage label=""

  cpu_usage=$(get_cpu_usage)
  mem_usage=$(get_memory_usage)

  local cpu_high=false
  local mem_high=false

  if [ "$cpu_usage" -ge "$THRESHOLD" ] 2>/dev/null; then
    cpu_high=true
  fi

  if [ "$mem_usage" -ge "$THRESHOLD" ] 2>/dev/null; then
    mem_high=true
  fi

  if [ "$cpu_high" = true ] || [ "$mem_high" = true ]; then
    # Build label based on what's high
    if [ "$cpu_high" = true ] && [ "$mem_high" = true ]; then
      label="CPU ${cpu_usage}% MEM ${mem_usage}%"
    elif [ "$cpu_high" = true ]; then
      label="CPU ${cpu_usage}%"
    else
      label="MEM ${mem_usage}%"
    fi

    sketchybar --set "$NAME" \
      drawing=on \
      icon.color="$COLOR_ERROR" \
      label="$label" \
      label.color="$COLOR_ERROR"
  else
    sketchybar --set "$NAME" drawing=off
  fi
}

case "$SENDER" in
  "forced") exit 0 ;;
  *) update ;;
esac
