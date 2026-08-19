#!/usr/bin/env bash

# IPC -> sketchybar bridge for the Paneru workspace cards.
#
# Paneru has no exec-on-change hook, so (unlike AeroSpace) it can't notify
# sketchybar directly. This long-lived process subscribes to Paneru's event
# socket and re-triggers a sketchybar event on each relevant change. Launched
# from items/spaces_paneru.sh; reconnects if the paneru daemon restarts.
# window_focused is included so the active-app highlight tracks focus.
#
# Single-instance guard via a pidfile. This REPLACES a `pkill -f
# paneru_provider.sh` that used to live in the launcher — that pattern also
# matched home-manager's `find … -exec bash <link> … <…/paneru_provider.sh>`
# during activation and SIGTERM'd it (sketchybar `--hotload` re-runs the item
# script when the file relinks), which broke `home-manager switch`. A pidfile
# can only ever match our own process.
PIDFILE="/tmp/paneru_provider.$(id -u).pid"
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
  exit 0 # another provider is already running
fi
echo $$ >"$PIDFILE"

export PATH="$HOME/.nix-profile/bin:/opt/homebrew/bin:$PATH"

while true; do
  paneru subscribe --json 2>/dev/null | while IFS= read -r line; do
    case "$line" in
    *virtual_workspace_changed* | *windows_changed* | *window_focused*)
      sketchybar --trigger paneru_workspace_change
      ;;
    esac
  done
  # subscribe exited (daemon restart / socket gone) — back off and reconnect.
  sleep 2
done
