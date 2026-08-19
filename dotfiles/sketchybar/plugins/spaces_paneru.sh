#!/usr/bin/env bash

# Full renderer for the Paneru workspace cards. Driven by paneru.driver on the
# paneru_workspace_change / paneru_loaded events. One state query, then one
# batched `sketchybar --set ...` updating every card: number/border colour
# (accent when active), separator visibility, and each window slot's icon,
# colour (accent for the focused window), click target and visibility.
#
# Workspaces are scoped to the active native macOS space — Paneru reuses the
# same virtual-workspace numbers on every native space, so we must filter by
# .active.native_workspace_id or empty same-numbered workspaces bleed in.
#
# App-icon click switches to the workspace then activates the app by bundle id
# (`open -b`). Paneru's IPC has no focus-by-window-id, so for an app with
# several windows on one workspace this raises the app generally, not the exact
# window — acceptable for the common one-window case.

source "$HOME/.config/sketchybar/env.sh"
export PATH="$HOME/.nix-profile/bin:$PATH" # paneru, jq

SKETCHYBAR="${SKETCHYBAR:-sketchybar}"
PANERU_BIN="$HOME/.nix-profile/bin/paneru"
WS_COUNT="${PANERU_WS_COUNT:-5}"
MAX_APPS="${PANERU_MAX_APPS:-5}"
# Faded tone for inactive workspaces / unfocused apps — dimmer than the
# active/focused accent but still clearly readable. COLOR_BORDER is the
# palette's text colour at ~40% alpha (a soft mid grey), brighter than the
# base03 muted tone which read as too faint here.
COLOR_FADED="$COLOR_BORDER"

state="$(paneru query state --json 2>/dev/null)"
[ -z "$state" ] && exit 0

active_ws="$(printf '%s' "$state" | jq -r '.active.virtual_workspace_number // 0')"

args=()
for ((i = 1; i <= WS_COUNT; i++)); do
  # app_name \t bundle_id \t focused  for workspace i on the active native space
  mapfile -t rows < <(printf '%s' "$state" | jq -r --argjson n "$i" '
    .active.native_workspace_id as $nw
    | .virtual_workspaces[]
    | select(.native_workspace_id == $nw and .number == $n)
    | .windows[]? | [.app_name, .bundle_id, (.focused | tostring)] | @tsv')

  # Active workspace is shown by its accent number (no per-card border now).
  if [ "$i" = "$active_ws" ]; then
    args+=(--set space."$i".num icon.color="$COLOR_ACCENT")
  else
    args+=(--set space."$i".num icon.color="$COLOR_FADED")
  fi

  if [ "${#rows[@]}" -gt 0 ]; then
    args+=(--set space."$i".sep drawing=on)
  else
    args+=(--set space."$i".sep drawing=off)
  fi

  j=1
  for row in "${rows[@]}"; do
    [ "$j" -gt "$MAX_APPS" ] && break
    IFS=$'\t' read -r app bundle focused <<<"$row"
    __icon_map "$app"
    glyph="${icon_result:-•}"
    if [ "$focused" = "true" ]; then
      wcolor="$COLOR_ACCENT"
    else
      wcolor="$COLOR_FADED"
    fi
    args+=(--set space."$i".win."$j" drawing=on icon="$glyph" icon.color="$wcolor"
      click_script="$PANERU_BIN send-cmd window virtualnum $i; /usr/bin/open -b '$bundle'")
    j=$((j + 1))
  done
  for (( ; j <= MAX_APPS; j++)); do
    args+=(--set space."$i".win."$j" drawing=off)
  done
done

$SKETCHYBAR "${args[@]}"
