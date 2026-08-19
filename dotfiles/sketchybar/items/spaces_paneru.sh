#!/usr/bin/env bash

##### Paneru Workspace Strip #####
# One continuous strip: [ 1 │ <icons>   2 │ <icons>  … ]. The number, the
# separator, and each window's app icon are SEPARATE items (fixed slots
# win.1..MAX_APPS) so every icon can be coloured (active-app highlight) and
# clicked independently — a single label couldn't do either. The renderer
# (plugins/spaces_paneru.sh) only toggles drawing + sets icon/colour/click per
# event; items are never added/removed at runtime. A single `spaces` bracket
# wraps the lot (no per-workspace borders — workspaces are separated by the gap
# before each number); the active workspace is shown by its accent number.
# State is pushed in from Paneru's IPC by paneru_provider.sh.

WS_COUNT="${PANERU_WS_COUNT:-5}"
MAX_APPS="${PANERU_MAX_APPS:-5}"
PANERU_BIN="$HOME/.nix-profile/bin/paneru"

# Start the IPC -> sketchybar bridge. The provider self-guards against running
# more than one instance (pidfile), so this is safe to call on every (re)load —
# and crucially carries no `pkill`, which during activation could match (and
# kill) home-manager's own link process. See plugins/paneru_provider.sh.
"$PLUGIN_DIR/paneru_provider.sh" >/dev/null 2>&1 &

for ((i = 1; i <= WS_COUNT; i++)); do
  # Workspace number (click switches workspace). The left padding is the gap
  # that separates one workspace from the previous one.
  sketchybar --add item space."$i".num left \
    --set space."$i".num \
    icon="$i" \
    icon.font="$FONT_MONO:Bold:11.0" \
    icon.color="$COLOR_PINK" \
    padding_left=10 padding_right=0 \
    icon.padding_left=0 icon.padding_right=3 \
    label.drawing=off \
    click_script="$PANERU_BIN send-cmd window virtualnum $i"

  # Separator between number and icons (hidden until the workspace has apps).
  sketchybar --add item space."$i".sep left \
    --set space."$i".sep \
    icon="│" \
    icon.font="$FONT_FAMILY:Regular:10.0" \
    icon.color="$COLOR_PINK" \
    padding_left=0 padding_right=0 \
    icon.padding_left=0 icon.padding_right=2 \
    label.drawing=off \
    drawing=off

  # App-icon slots (hidden until filled by the renderer).
  for ((j = 1; j <= MAX_APPS; j++)); do
    sketchybar --add item space."$i".win."$j" left \
      --set space."$i".win."$j" \
      icon.font="sketchybar-app-font:Regular:12.0" \
      icon.color="$COLOR_PINK" \
      padding_left=0 padding_right=0 \
      icon.padding_left=2 icon.padding_right=2 \
      label.drawing=off \
      drawing=off
  done
done

# Trailing spacer so the last app icon isn't flush against the bracket's right
# edge (sketchybar ignores background.padding on brackets). An empty but DRAWN
# icon (icon.drawing=on) makes icon.padding_left count as real, invisible width
# — a hidden icon's padding is ignored. It matches the bracket regex below, so
# it sits inside the box at the far right. The left end is already inset by the
# first number's own padding_left.
sketchybar --add item space.tail left \
  --set space.tail \
  icon="" icon.drawing=on icon.padding_left=4 icon.padding_right=0 \
  label.drawing=off background.drawing=off \
  padding_left=0 padding_right=0

# Single continuous bracket around every workspace item (no inter-workspace
# borders). Driver item below is excluded — it isn't a space.* item.
sketchybar --add bracket spaces '/space\..*/' \
  --set spaces \
  "background.color=$COLOR_ITEM_BACKGROUND" \
  background.corner_radius=6 \
  background.height=22 \
  background.border_width=1 \
  "background.border_color=$COLOR_BORDER"

# Hidden driver item: a single script that re-renders every card on each event.
# updates=on so it runs even though drawing=off (default updates=when_shown).
sketchybar --add item paneru.driver left \
  --set paneru.driver drawing=off updates=on \
  script="$PLUGIN_DIR/spaces_paneru.sh" \
  --subscribe paneru.driver paneru_workspace_change paneru_loaded

# Initial paint.
sketchybar --trigger paneru_workspace_change
