#!/usr/bin/env bash

# Shared environment for sketchybar plugins.
# Source this at the top of plugin scripts instead of
# sourcing colors.sh and icon_map.sh individually.

# Ensure homebrew and nix binaries are available
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"

# Colors
source "$HOME/.config/sketchybar/colors.sh"

# App icon mapping (from sketchybar-app-font nix package)
source "$HOME/.nix-profile/bin/icon_map.sh" 2>/dev/null
