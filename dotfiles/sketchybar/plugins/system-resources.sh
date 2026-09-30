#!/usr/bin/env bash

source "$HOME/.config/sketchybar/env.sh"

THRESHOLD=90

get_cpu_usage() {
  iostat -c 2 -w 1 2>/dev/null | awk '
    # CPU fields precede the three trailing load averages for any disk count.
    $1 ~ /^[0-9]/ { idle = $(NF - 3) }
    END {
      if (idle == "") print 0
      else printf "%.0f\n", 100 - idle
    }
  '
}

get_memory_usage() {
  local free_pct
  free_pct=$(memory_pressure 2>/dev/null | grep "System-wide memory free percentage" | awk '{print $5}' | tr -d '%')
  if [ -n "$free_pct" ]; then
    echo $((100 - free_pct))
  else
    echo 0
  fi
}

update() {
  local cpu_usage mem_usage
  local cpu_icon_color cpu_icon_font cpu_label_color cpu_label_font
  local mem_icon_color mem_icon_font mem_label_color mem_label_font

  cpu_usage=$(get_cpu_usage)
  mem_usage=$(get_memory_usage)
  cpu_icon_color="$COLOR_BLACK4"
  cpu_icon_font="SF Pro:Semibold:13.0"
  cpu_label_color="$COLOR_LABEL_SECONDARY"
  cpu_label_font="SF Mono:Medium:11.0"
  mem_icon_color="$COLOR_BLACK4"
  mem_icon_font="SF Pro:Semibold:13.0"
  mem_label_color="$COLOR_LABEL_SECONDARY"
  mem_label_font="SF Mono:Medium:11.0"

  if [ "$cpu_usage" -ge "$THRESHOLD" ] 2>/dev/null; then
    cpu_icon_color="$COLOR_ERROR"
    cpu_icon_font="SF Pro:Semibold:15.0"
    cpu_label_color="$COLOR_ERROR"
    cpu_label_font="SF Mono:Bold:11.0"
  fi
  if [ "$mem_usage" -ge "$THRESHOLD" ] 2>/dev/null; then
    mem_icon_color="$COLOR_ERROR"
    mem_icon_font="SF Pro:Semibold:15.0"
    mem_label_color="$COLOR_ERROR"
    mem_label_font="SF Mono:Bold:11.0"
  fi

  sketchybar \
    --set system_resources.cpu \
    icon.color="$cpu_icon_color" \
    icon.font="$cpu_icon_font" \
    label="${cpu_usage}%" \
    label.color="$cpu_label_color" \
    label.font="$cpu_label_font" \
    --set system_resources.ram \
    icon.color="$mem_icon_color" \
    icon.font="$mem_icon_font" \
    label="${mem_usage}%" \
    label.color="$mem_label_color" \
    label.font="$mem_label_font"
}

update
