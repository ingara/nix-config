#!/usr/bin/env bash
# Focus Cursor window by project name
# Usage: focus_cursor.sh <project-name>
#
# Examples:
#   focus_cursor.sh screening    -> Focus "screening" project window
#   focus_cursor.sh screening-2  -> Focus "screening-2" project window
#
# Window Detection:
#   Cursor windows have titles like:
#     - "filename.ext — project-name"
#     - "project-name" (no file open)
#   Project name is extracted from the end of the title

project_name="${1:-screening}"

window_id=$(yabai -m query --windows | jq -r --arg name "$project_name" '
# Get all Cursor windows and extract project names
[.[] | select(.app == "Cursor") | {
  id: .id,
  title: .title,
  # Extract project name from end of title (e.g., "screening" or "screening-2")
  project: (.title | capture("(?:—\\s*)?(?<p>screening(?:-\\d+)?)$") | .p)
}] |
# Filter to requested project name
map(select(.project == $name)) |
# Sort by ID and take first (lowest ID = earliest created)
sort_by(.id) |
.[0].id // empty
')

if [ -n "$window_id" ]; then
  yabai -m window --focus "$window_id"
else
  echo "Cursor window not found for project: $project_name" >&2
  exit 1
fi
