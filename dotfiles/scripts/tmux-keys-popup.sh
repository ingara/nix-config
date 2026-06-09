#!/usr/bin/env bash
# Fuzzy-find tmux key bindings in a single key-table and invoke the selection.
# Usage: tmux-keys-popup <table>      # e.g. prefix, root, copy-mode-vi
#
# Uses `list-keys -aN` so every bind shows up: those with a `-N "..."`
# note display the note; the rest fall back to the raw command. Custom
# binds carrying group-prefixed notes (`[Window] ...`) cluster naturally
# under fzf's filter.
#
# Selection dispatches via `tmux send-keys` so the bound action fires
# exactly as if the key were pressed manually (format-spec expansion,
# `-r` repeat semantics, etc. all behave normally).
set -euo pipefail

table="${1:-prefix}"

selected=$(
  tmux list-keys -aN -T "$table" 2>/dev/null |
    awk 'NF >= 2' |
    fzf \
      --prompt="[$table] " \
      --reverse \
      --no-sort \
      --height=90% \
      --with-nth=1..
) || exit 0

# First whitespace-separated token is the key (named keys like `C-Space`,
# `M-?`, `S-F4` have no internal whitespace; printable single-chars likewise).
key=$(awk '{print $1}' <<<"$selected")
[ -z "$key" ] && exit 0

if [ "$table" = "prefix" ]; then
  prefix_key=$(tmux show-options -gv prefix)
  tmux send-keys "$prefix_key" "$key"
else
  tmux send-keys "$key"
fi
