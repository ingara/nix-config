#!/usr/bin/env bash
# Focus specific Cursor window by project number and type
# Usage: focus_cursor.sh [1-9] [main|agent]
#
# Examples:
#   focus_cursor.sh 1 main   -> Focus first project's main window
#   focus_cursor.sh 2 agent  -> Focus second project's agent window
#
# Window Detection:
#   Cursor windows have titles like:
#     - "filename.ext — project-name" (main window with file open)
#     - "project-name" (main window with no file open)
#     - "New Chat — project-name" (agent window)
#     - "Chat description — project-name" (agent window)
#
#   Detection logic:
#     - Has file extension before "—" -> main window
#     - No "—" separator -> main window (no file open)
#     - Otherwise -> agent window

project_num="${1:-1}"
window_type="${2:-main}"

window_id=$(yabai -m query --windows | jq -r --argjson num "$project_num" --arg type "$window_type" '
# Step 1: Get all Cursor windows and classify them
[.[] | select(.app == "Cursor") | {
  id: .id,
  title: .title,
  # Extract project name from end of title (e.g., "screening" or "screening-2")
  project: (.title | capture("(?:—\\s*)?(?<p>screening(?:-\\d+)?)$") | .p),
  # Classify as main or agent window based on title pattern
  type: (
    # Pattern 1: "file.ext — project" -> main window
    if ((.title | split(" — ")[0]) | test("\\.[a-z]{2,4}$")) then "main"
    # Pattern 2: "project" (no separator) -> main window
    elif (.title | test("—") | not) then "main"
    # Pattern 3: anything else with separator -> agent window
    else "agent"
    end
  )
}] |
# Step 2: Sort by ID first for deterministic ordering
sort_by(.id) |
# Step 3: Group windows by project name
group_by(.project) |
# Step 4: Add min_id to each group for stable sorting
# (group_by doesn'\''t guarantee order, so we need explicit sorting)
map({
  project: .[0].project,
  min_id: (map(.id) | min),
  windows: .
}) |
# Step 5: Sort groups by their minimum window ID
# This ensures project 1 is always the earliest created project
sort_by(.min_id) |
# Step 6: Select the requested project (1-indexed)
.[$num - 1] // {windows: []} |
.windows |
# Step 7: Filter to requested window type (main or agent)
map(select(.type == $type)) |
# Step 8: Sort by ID and take first (lowest ID = earliest created)
sort_by(.id) |
.[0].id // empty
')

if [ -n "$window_id" ]; then
  yabai -m window --focus "$window_id"
else
  echo "Cursor window not found: project $project_num, type $window_type" >&2
  exit 1
fi
