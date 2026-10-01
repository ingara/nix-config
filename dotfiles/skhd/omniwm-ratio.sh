#!/bin/sh
# Asymmetric column split around the focused window. Set the neighbor first so
# the pair does not exceed the viewport while the focused column grows.
# OmniWM v0.7.4: query windows --focused --fields id --format tsv returns an
# ID-first row after its header; IDs are opaque and valid only for this session.
O=/Applications/OmniWM.app/Contents/MacOS/omniwmctl
fid() {
  rows=$("$O" query windows --focused --fields id --format tsv) || return 1
  printf '%s\n' "$rows" | /usr/bin/tail -n +2 | /usr/bin/cut -f1
}

orig=$(fid) || exit 1
[ -n "$orig" ] && [ "$orig" != '-' ] || exit 0
now=$orig
if "$O" command focus right >/dev/null 2>&1; then
  now=$(fid) || exit 1
fi
if [ "$now" = "$orig" ]; then
  if "$O" command focus left >/dev/null 2>&1; then
    now=$(fid) || exit 1
  fi
fi
[ -n "$now" ] && [ "$now" != '-' ] && [ "$now" != "$orig" ] || exit 0
trap '"$O" window focus "$orig" >/dev/null 2>&1' EXIT
"$O" command set-container-primary-span "$2" || exit 1
"$O" window focus "$orig" || exit 1
"$O" command set-container-primary-span "$1"
