#!/usr/bin/env bash
# Detect display configuration and return setup name

if ! command -v jq &>/dev/null; then
  echo "mobile"
  exit 0
fi

displays_json=$(system_profiler SPDisplaysDataType -json)
display_info=$(echo "$displays_json" | jq -r '.SPDisplaysDataType[0].spdisplays_ndrvs[] | "\(._name // "Unknown")|\(.spdisplays_connection_type // "external")"')

has_builtin=false
has_lg_ultrafine=false
has_samsung=false
has_acer=false
total_displays=0

while IFS='|' read -r name connection; do
  total_displays=$((total_displays + 1))
  case "$connection" in
    "spdisplays_internal") has_builtin=true ;;
  esac
  case "$name" in
    *"LG ULTRAFINE"*) has_lg_ultrafine=true ;;
    *"Samsung"*|*"SAMSUNG"*|*"Odyssey"*|*"G9"*) has_samsung=true ;;
    *"Acer"*|*"ACER"*|*"Predator"*|*"PREDATOR"*) has_acer=true ;;
  esac
done <<< "$display_info"

# Primary detection based on external monitors
if [ "$has_lg_ultrafine" = true ]; then
  echo "office"
elif [ "$has_samsung" = true ] || [ "$has_acer" = true ]; then
  echo "home"
else
  echo "mobile"
fi
