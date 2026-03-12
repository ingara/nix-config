#!/usr/bin/env bash
# Apply workspace setup based on detected or specified configuration
# Note: Workspace-to-monitor assignment is handled by aerospace.toml config
# This script now just arranges the dev workspace and shows notification

setup="${1:-auto}"
[ "$setup" = "auto" ] && setup=$(~/.config/aerospace/scripts/detect_setup.sh)

echo "Applying $setup setup..."

# Arrange dev workspace
~/.config/aerospace/scripts/arrange_dev.sh 2>/dev/null || true

terminal-notifier -title "AeroSpace" -message "$setup setup loaded!"
