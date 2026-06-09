#!/usr/bin/env sh
# Outputs styled session name for zjstatus (dynamic rendermode).
# Local segment uses LOCAL_BG; SSH uses SSH_BG. Colors come from a
# Nix-generated colors file driven by myOptions.theme.scheme.

. "$HOME/.config/zellij/session-colors.sh"

session="${ZELLIJ_SESSION_NAME:-unknown}"

if [ -n "$SSH_CONNECTION" ] || [ -n "$SSH_TTY" ] || [ -n "$SSH_CLIENT" ]; then
  host="$(hostname -s)"
  echo "#[bg=${SSH_BG},fg=${BASE_BG},bold] ${session}@${host} "
else
  echo "#[bg=${LOCAL_BG},fg=${BASE_BG},bold] ${session} "
fi
