#!/usr/bin/env bash

# Get display information as JSON
displays_json=$(system_profiler SPDisplaysDataType -json)

# Extract display names and connection types
display_info=$(echo "$displays_json" | jq -r '.SPDisplaysDataType[0].spdisplays_ndrvs[] | "\(._name // "Unknown")|\(.spdisplays_connection_type // "external")"')

# Count displays and categorize them
has_builtin=false
has_lg_ultrafine=false
has_samsung=false
has_acer=false
total_displays=0

while IFS='|' read -r name connection; do
  total_displays=$((total_displays + 1))
  
  case "$connection" in
    "spdisplays_internal")
      has_builtin=true
      ;;
  esac
  
  case "$name" in
    *"LG ULTRAFINE"*)
      has_lg_ultrafine=true
      ;;
    *"Samsung"*|*"SAMSUNG"*|*"Odyssey"*|*"G9"*)
      has_samsung=true
      ;;
    *"Acer"*|*"ACER"*|*"Predator"*|*"PREDATOR"*)
      has_acer=true
      ;;
  esac
done <<< "$display_info"

# Determine setup based on display combination
if [ "$total_displays" -eq 1 ] && [ "$has_builtin" = true ]; then
  echo "mobile"
elif [ "$has_builtin" = true ] && [ "$has_lg_ultrafine" = true ]; then
  echo "office"
elif [ "$has_samsung" = true ] && [ "$has_acer" = true ]; then
  echo "home"
elif [ "$has_lg_ultrafine" = true ] && [ "$total_displays" -eq 1 ]; then
  # LG only (MacBook closed in office setup)
  echo "office"
elif [ "$total_displays" -eq 2 ] && [ "$has_builtin" = false ]; then
  # Two external displays, MacBook likely closed
  echo "home"
else
  echo "unknown"
fi
