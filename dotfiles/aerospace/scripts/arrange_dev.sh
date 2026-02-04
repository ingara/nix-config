#!/bin/bash
# Arrange dev workspace: Arc (left tiles) | Editors (right accordion)

# Focus dev workspace
aerospace workspace dev

# Get window IDs
arc_id=$(aerospace list-windows --workspace dev --format '%{window-id}|%{app-name}' | grep '|Arc$' | head -1 | cut -d'|' -f1)
editor_ids=$(aerospace list-windows --workspace dev --format '%{window-id}|%{app-name}' | grep -E '\|(Cursor|Code|Claude)$' | cut -d'|' -f1)

if [ -z "$arc_id" ] || [ -z "$editor_ids" ]; then
  echo "Missing Arc or editor windows"
  exit 0
fi

# Set workspace to tiles (BSP base)
aerospace layout tiles horizontal

# Focus Arc and ensure it's first
aerospace focus --window-id "$arc_id"

# Join first editor with Arc (creates nested container)
first_editor=$(echo "$editor_ids" | head -1)
aerospace focus --window-id "$first_editor"
aerospace join-with left

# Remaining editors join the accordion
for editor_id in $(echo "$editor_ids" | tail -n +2); do
  aerospace focus --window-id "$editor_id"
  aerospace join-with up  # Stack vertically in accordion
done

# Set the editor container to accordion
aerospace focus --window-id "$first_editor"
aerospace layout accordion vertical

echo "Dev layout arranged: Arc (left) | Editors accordion (right)"
