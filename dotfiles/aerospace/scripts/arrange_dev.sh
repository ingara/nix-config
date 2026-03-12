#!/bin/bash
# Arrange dev workspace: Arc (left tiles) | Editors (right vertical accordion)
# Strategy: stash editors in temp workspace, bring them back one at a time,
# use join-with to create the group, then move to add to it.

aerospace workspace dev

# Get window IDs
arc_id=$(aerospace list-windows --workspace dev --format '%{window-id}|%{app-name}' | grep '|Arc$' | head -1 | cut -d'|' -f1)
editor_ids=$(aerospace list-windows --workspace dev --format '%{window-id}|%{app-name}' | grep -E '\|(Cursor|Code|Claude)$' | cut -d'|' -f1)

if [ -z "$arc_id" ] || [ -z "$editor_ids" ]; then
  echo "Need both Arc and editor windows on dev workspace" >&2
  exit 0
fi

editor_array=()
while IFS= read -r id; do
  [ -n "$id" ] && editor_array+=("$id")
done <<< "$editor_ids"

if [ ${#editor_array[@]} -lt 2 ]; then
  aerospace flatten-workspace-tree
  aerospace layout tiles horizontal
  exit 0
fi

# Phase 1: Clean slate
aerospace flatten-workspace-tree

# Stash editors in temp workspace (instant, no visual jumping)
for id in "${editor_array[@]}"; do
  aerospace focus --window-id "$id"
  aerospace move-node-to-workspace _arrange_tmp
done

# Dev now has only Arc
aerospace workspace dev
aerospace focus --window-id "$arc_id"
aerospace layout tiles horizontal

# Phase 2: Build the editor group
# Bring first editor back (lands as sibling of Arc at root)
aerospace workspace _arrange_tmp
aerospace focus --window-id "${editor_array[0]}"
aerospace move-node-to-workspace dev

# Bring second editor back
aerospace workspace _arrange_tmp
aerospace focus --window-id "${editor_array[1]}"
aerospace move-node-to-workspace dev

# Join second editor with first: creates a 2-window vertical container
# join-with left from E1 → V[E0, E1]  (E1's left neighbor is E0)
aerospace workspace dev
aerospace focus --window-id "${editor_array[1]}"
aerospace join-with left

# Bring remaining editors back and MOVE (not join) them into the container
# move does deepMoveIn — adds to the container without nesting
for ((i=2; i<${#editor_array[@]}; i++)); do
  aerospace workspace _arrange_tmp
  aerospace focus --window-id "${editor_array[$i]}"
  aerospace move-node-to-workspace dev
  aerospace workspace dev
  aerospace focus --window-id "${editor_array[$i]}"
  aerospace move left
done

# Phase 3: Set layout
aerospace focus --window-id "${editor_array[0]}"
aerospace layout accordion vertical

echo "Dev layout: Arc (left) | Editors accordion (right)"
