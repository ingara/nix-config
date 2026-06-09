#!/usr/bin/env bash
# Emit a Nerd Font folder icon + label for the given cwd, for tmux's status bar.
# Args: $1 = absolute path of the pane's cwd (typically #{pane_current_path}).
#
# Inside a git repo:    org/repo  (from origin URL; falls back to repo dirname)
#   Inside a worktree:  appends :worktreename
# Outside a git repo:   ~/path    (home-rel; truncated to ".../basename" when long)
#
# Plain output; tmux.nix wraps the result with static styling. The git-branch
# icon now lives with the git-status segment on the right side of the bar.
set -u

cwd="${1:-${PWD:-}}"
[[ -z $cwd || ! -d $cwd ]] && exit 0

ICON_FOLDER=$'' # nf-fa-folder_o

if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  # org/repo from the origin URL — worktrees share an origin with the main
  # repo, so this gives the canonical name in both cases.
  origin="$(git -C "$cwd" config --get remote.origin.url 2>/dev/null || true)"
  slug=""
  if [[ -n $origin ]]; then
    slug="$(printf '%s' "$origin" |
      sed -E 's|\.git$||; s|^.*[:/]([^/]+/[^/]+)$|\1|')"
  fi
  if [[ -z $slug ]]; then
    toplevel="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)"
    slug="${toplevel##*/}"
  fi

  # Worktree-awareness: compare current worktree's top-level against the
  # main worktree's path (first entry in `git worktree list --porcelain`).
  # When they differ, we're in a linked worktree; append its directory
  # name so e.g. `soolv/screening:agent-workflow-cleanup` rather than just
  # `soolv/screening` (which loses the worktree identity).
  worktree_path="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)"
  main_worktree="$(git -C "$cwd" worktree list --porcelain 2>/dev/null |
    awk '/^worktree / { print $2; exit }')"
  if [[ -n $worktree_path && -n $main_worktree && $worktree_path != "$main_worktree" ]]; then
    slug="${slug}:${worktree_path##*/}"
  fi

  printf '%s  %s' "$ICON_FOLDER" "$slug"
else
  short="${cwd/#$HOME/\~}"
  if ((${#short} > 32)); then
    short="…/${short##*/}"
  fi
  printf '%s  %s' "$ICON_FOLDER" "$short"
fi
