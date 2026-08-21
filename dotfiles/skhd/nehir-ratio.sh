#!/bin/sh
# nehir-ratio.sh <focused-width> <neighbor-width> — asymmetric column split
# (Option+R / Option+Shift+R in nehir.skhd). Sets the focused column to $1 and
# the adjacent column (right if one exists, else left) to $2, then returns
# focus. Single column: no-op.
#
# Order matters: the neighbor (the shrinking side in both ratio directions) is
# set BEFORE the focused column grows, so the pair never overflows the
# viewport mid-sequence. Nehir centers the focused column in the viewport when
# its width changes, which leaves an exact-fit pair offset by half the growth
# — the closing focus hop to the neighbor re-reveals its outer edge, which
# packs the pair (minimal-reveal on focus change), before focus returns.
# (scroll-viewport can't do this: it overscrolls past the strip edge rather
# than clamping.)
#
# nehirctl IPC is synchronous for focus state (a query right after a focus
# command returns the new focus), but resize *animations* are not: a reveal
# issued mid-animation computes against in-flight geometry and mis-packs, and
# no fixed sleep is reliably past the animation under rapid re-presses. Hence
# the geometry-stability poll before the pack hop: sample the focused frame
# until two consecutive reads match. (Verified against Nehir 0.5.1.)
#
# Only /usr/bin tools + absolute paths: the skhd agent's launchd PATH has
# neither Homebrew nor the Nix profile.
N=/Applications/Nehir.app/Contents/MacOS/nehirctl

fid() { "$N" query windows --focused --fields id --format tsv | tail -n +2 | cut -f1; }

orig=$(fid)
[ -n "$orig" ] || exit 0
dir=right
"$N" command focus right
now=$(fid)
if [ "$now" = "$orig" ]; then
  dir=left
  "$N" command focus left
  now=$(fid)
fi
[ "$now" != "$orig" ] || exit 0
"$N" command set-column-width "$2"
"$N" window focus "$orig"
"$N" command set-column-width "$1"
prev=
for _ in 1 2 3 4 5 6 7 8; do
  cur=$("$N" query windows --focused --format json | grep -E '"(x|width)"' | tr -d ' ')
  [ -n "$cur" ] && [ "$cur" = "$prev" ] && break
  prev=$cur
  sleep 0.06
done
"$N" command focus "$dir"
"$N" window focus "$orig"
