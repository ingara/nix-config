#!/usr/bin/env bash
# Emit a compact git status for tmux's status bar.
# Args: $1 = absolute path of the pane's cwd (typically #{pane_current_path}).
#       $2 = max branch width in chars (default 24). Long branch names —
#            common with Graphite stacks (`ingar/01-19-feat_…`) — get
#            tail-truncated with an ellipsis so the clock on the right
#            doesn't fall off the bar.
#
# Format:   branch [●N] [↑M] [↓K]
#    = nf-oct-git_branch (Nerd Font); the git-icon lives here rather
#       than on the cwd segment so the two contexts are visually distinct
#   ●N = N dirty/untracked files (porcelain count)
#   ↑M = M commits ahead of upstream
#   ↓K = K commits behind upstream
#
# Emits nothing when outside a git repo.
set -u

# This script fires every status-interval (5 s). `git status` opportunistically
# grabs the index lock to refresh cached stat info, which races against an
# interactive `git commit` in the same repo (seen as `Unable to create
# '.git/index.lock'`). GIT_OPTIONAL_LOCKS=0 tells git to skip lock-acquiring
# optimisations for advisory reads — designed exactly for pollers like this.
export GIT_OPTIONAL_LOCKS=0

cwd="${1:-${PWD:-}}"
max_branch="${2:-24}"
[[ -z $cwd || ! -d $cwd ]] && exit 0

git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

branch="$(git -C "$cwd" symbolic-ref --quiet --short HEAD 2>/dev/null ||
  git -C "$cwd" rev-parse --short HEAD 2>/dev/null ||
  echo '?')"

if ((max_branch > 0 && ${#branch} > max_branch)); then
  branch="${branch:0:max_branch-1}…"
fi

dirty="$(git -C "$cwd" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"

# rev-list --left-right --count A...B emits "behind\tahead" against the
# upstream of HEAD. Empty when no upstream is configured.
ab="$(git -C "$cwd" rev-list --left-right --count '@{u}...HEAD' 2>/dev/null || true)"
behind="${ab%%	*}"
ahead="${ab##*	}"
[[ -z $behind ]] && behind=0
[[ -z $ahead ]] && ahead=0

ICON_GIT=$'' # nf-oct-git_branch
out="$ICON_GIT  $branch"
((dirty > 0)) && out+=" ●$dirty"
((ahead > 0)) && out+=" ↑$ahead"
((behind > 0)) && out+=" ↓$behind"
printf '%s' "$out"
