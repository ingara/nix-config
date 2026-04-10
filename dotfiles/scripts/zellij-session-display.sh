#!/usr/bin/env sh
# Outputs styled session name for zjstatus (dynamic rendermode).
# Blue locally, pink with hostname over SSH.

session="${ZELLIJ_SESSION_NAME:-unknown}"

if [ -n "$SSH_CONNECTION" ] || [ -n "$SSH_TTY" ] || [ -n "$SSH_CLIENT" ]; then
  host="$(hostname -s)"
  echo "#[bg=#f5bde6,fg=#24273a,bold] ${session}@${host} "
else
  echo "#[bg=#8aadf4,fg=#24273a,bold] ${session} "
fi
