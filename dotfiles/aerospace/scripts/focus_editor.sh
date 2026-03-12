#!/bin/bash
EDITOR_PATTERN='\|(Code|Cursor|Claude)$'

current_ws=$(aerospace list-workspaces --focused)

editor_ids=()
while IFS= read -r line; do
  [ -z "$line" ] && continue
  editor_ids+=("$(echo "$line" | cut -d'|' -f1)")
done <<< "$(aerospace list-windows --workspace dev --format '%{window-id}|%{app-name}' \
  | grep -E "$EDITOR_PATTERN")"

if [ ${#editor_ids[@]} -eq 0 ]; then
  aerospace workspace dev
  exit 0
fi

if [ "$current_ws" != "dev" ]; then
  aerospace focus --window-id "${editor_ids[0]}"
  exit 0
fi

focused_info=$(aerospace list-windows --focused --format '%{window-id}|%{app-name}')
focused_id=$(echo "$focused_info" | cut -d'|' -f1)
focused_app=$(echo "$focused_info" | cut -d'|' -f2)

if ! echo "$focused_app" | grep -qE '^(Code|Cursor|Claude)$'; then
  aerospace focus --window-id "${editor_ids[0]}"
  exit 0
fi

for i in "${!editor_ids[@]}"; do
  if [ "${editor_ids[$i]}" = "$focused_id" ]; then
    next=$(( (i + 1) % ${#editor_ids[@]} ))
    aerospace focus --window-id "${editor_ids[$next]}"
    exit 0
  fi
done

aerospace focus --window-id "${editor_ids[0]}"
