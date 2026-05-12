#!/usr/bin/env bash
set -euo pipefail

# Terminal screensaver selector
# Run in a spare pane — press 1/2/3 to pick, anything else to quit.

show_menu() {
  clear
  printf '\n'
  printf '  \033[2m── screensaver ──\033[0m\n\n'
  printf '  1  cbonsai\n'
  printf '  2  lavat\n\n'
  printf '  \033[2many other key to exit\033[0m\n\n'
}

run_screensaver() {
  case "$1" in
  1) cbonsai -li --wait=10 --life=80 --time=0.1 ;;
  2) lavat ;;
  esac
}

while true; do
  show_menu
  read -rsn1 key
  case "$key" in
  1 | 2 | 3) run_screensaver "$key" ;;
  *) clear && exit 0 ;;
  esac
done
