#!/usr/bin/env bash

set -euo pipefail

# Snapshot tabs follow Herdr's position order, not their stable public numbers.
# NUL framing and the rev-parse sentinel preserve unusual path characters.
jq -j '
  .result.snapshot as $s
  | $s.workspaces[]? as $w
  | (first($s.tabs[]? | select(.workspace_id == $w.workspace_id) | .tab_id) // null) as $tab
  | (first($s.layouts[]? | select(.tab_id == $tab) | .panes[0].pane_id) // null) as $pane
  | (first($s.panes[]? | select(.pane_id == $pane) | .cwd) // "") as $cwd
  | [$w.workspace_id, ($w.worktree.repo_key // ""), ($w.worktree.repo_name // ""),
      (if $w.worktree == null then $cwd else "" end)]
  | .[] | (., "\u0000")
' | {
  while IFS= read -r -d '' id && IFS= read -r -d '' key &&
    IFS= read -r -d '' name && IFS= read -r -d '' cwd; do
    if [ -n "$cwd" ]; then
      if resolved="$(git -C "$cwd" rev-parse --is-bare-repository --path-format=absolute --git-common-dir 2>/dev/null && printf .)" &&
        [[ $resolved == false$'\n'* ]]; then
        key="${resolved#*$'\n'}"
        key="${key%$'\n'.}"
        name="${key##*/}"
        parent="${key%/*}"
        if [ "$name" = .git ]; then
          name="${parent##*/}"
        elif [ "$name" = .bare ] && [ -e "$parent/.git" ]; then
          # Herdr names an embedded .bare after the container pointing to it.
          if container="$(git -C "$parent" rev-parse --absolute-git-dir 2>/dev/null && printf .)" &&
            [ "${container%$'\n'.}" = "$key" ]; then
            name="${parent##*/}"
          fi
        fi
      fi
    fi
    printf '%s\0%s\0%s\0' "$id" "$key" "${name:-repo}"
  done
} | jq -Rs '
  split("\u0000") | .[:-1]
  | [range(0; length; 3) as $i | {key:.[$i], value:
      (if .[$i+1] == "" then null else {repo_key:.[$i+1], repo_name:.[$i+2]} end)}]
  | from_entries
'
