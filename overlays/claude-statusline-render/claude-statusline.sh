#!/usr/bin/env bash
# Claude Code statusLine renderer.
#
# Reads the statusLine JSON payload on stdin and prints two lines:
#
#   repo [⧉ worktree] on branch <status>  │  Model · effort [· ▸agent] [· ✎style]
#   ctx <bar> NN%   5h <bar> NN% ⇥HH:MM   7d <bar> NN% ⇥Day HH
#
# Everything but the branch and working-tree status comes from the payload —
# `workspace.repo.name`, `workspace.git_worktree`, `effort.level`,
# `context_window.used_percentage` and both `rate_limits` windows are all
# fields Claude Code hands us, so the only subprocesses are one `jq` and one
# `git status`.
#
# Bar width is fixed because there is no width signal to adapt to: stdout is a
# pipe, and Claude Code does not export COLUMNS to the statusLine child.
#
# Set CLAUDE_STATUSLINE_DEBUG=<path> to dump the raw payload there; it is the
# only way to inspect what Claude Code actually sends.
#
# Published at: https://gist.github.com/ingara/2e5e9c041351700c713093e96205b9cb
# — check there for the latest version.
#
# Requires bash >= 4.2 (printf '%(%s)T'), jq, and git on PATH.

set -o errexit
set -o nounset
set -o pipefail

blob=$(cat)

if [ -n "${CLAUDE_STATUSLINE_DEBUG:-}" ]; then
  printf '%s' "$blob" >"$CLAUDE_STATUSLINE_DEBUG" || true
fi

# ── palette ────────────────────────────────────────────────────────────────
# Base16 slots, overridable from a theme file. The defaults apply when that
# file is absent.
base03=6e6a86 # muted — labels, separators
base08=eb6f92 # red    — over budget, behind upstream, conflicts
base09=f6c177 # orange — approaching budget
base0A=f6c177 # yellow — unstaged
base0B=31748f # green  — branch, staged, clean
base0C=9ccfd8 # cyan   — meters at rest, ahead of upstream
base0D=3e8fb0 # blue   — repo
base0E=c4a7e7 # magenta— model, worktree

theme="${XDG_CONFIG_HOME:-${HOME:-}/.config}/claude-statusline/theme.env"
if [ -f "$theme" ]; then
  # Parsed rather than sourced: this file may be generated, but a status line
  # has no business being an arbitrary-code entry point.
  #
  # `|| [ -n "$key" ]` keeps the final line when the file has no trailing
  # newline, where `read` returns non-zero having already filled the variables.
  while IFS='=' read -r key val || [ -n "$key" ]; do
    case $key in base0[0-9A-F]) ;; *) continue ;; esac
    case $val in
    [0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]) ;;
    *) continue ;;
    esac
    printf -v "$key" '%s' "$val"
  done <"$theme"
fi

setcolor() {
  printf -v "$1" '\e[38;2;%d;%d;%dm' \
    "$((16#${2:0:2}))" "$((16#${2:2:2}))" "$((16#${2:4:2}))"
}
setcolor DIM "$base03"
setcolor RED "$base08"
setcolor ORG "$base09"
setcolor YEL "$base0A"
setcolor GRN "$base0B"
setcolor CYA "$base0C"
setcolor BLU "$base0D"
setcolor MAG "$base0E"
R=$'\e[0m'

# ── payload ────────────────────────────────────────────────────────────────
# Unit separator, not @tsv: tab is IFS whitespace, so bash would collapse runs
# of it and every absent field would shift the rest of the assignment left.
#
# Every field feeding arithmetic goes through `tonumber?`, which yields nothing
# for anything non-numeric and so arrives as the empty string the guards below
# already handle. This is an unversioned contract we do not control, and a
# string reaching `$(( ))` is fatal under `nounset` — it takes the whole line
# down, not just one field.
#
# The separator reaches jq as --arg rather than as a \u001f escape in the
# program text: rendering tools can rewrite \uXXXX into the literal control
# byte (`gh gist view` does), which jq rejects at compile time.
us=$'\x1f'
IFS=$us read -r repo worktree cwd model effort agent ostyle \
  ctx five five_at seven seven_at <<<"$(
    printf '%s' "$blob" | jq -r --arg us "$us" '
    [ (.workspace.repo.name              // ""),
      (.workspace.git_worktree           // .worktree.name // ""),
      (.workspace.current_dir            // .cwd // ""),
      (.model.display_name               // ""),
      (.effort.level                     // ""),
      (.agent.name                       // ""),
      (.output_style.name                // ""),
      ((.context_window.used_percentage        | tonumber? | floor) // ""),
      ((.rate_limits.five_hour.used_percentage | tonumber? | floor) // ""),
      ((.rate_limits.five_hour.resets_at       | tonumber? | floor) // ""),
      ((.rate_limits.seven_day.used_percentage | tonumber? | floor) // ""),
      ((.rate_limits.seven_day.resets_at       | tonumber? | floor) // "")
    ] | map(tostring | gsub("[\n\r]"; " ")) | join($us)'
  )"

[ -n "$cwd" ] || cwd=$PWD

# ── git ────────────────────────────────────────────────────────────────────
branch=''
detached=''
ahead=0 behind=0 staged=0 unstaged=0 untracked=0 conflicts=0
in_repo=0

if gitout=$(git --no-optional-locks -C "$cwd" status --porcelain=v2 --branch 2>/dev/null); then
  in_repo=1
  while IFS= read -r line; do
    case $line in
    '# branch.oid '*) detached=${line#'# branch.oid '} ;;
    '# branch.head '*) branch=${line#'# branch.head '} ;;
    '# branch.ab '*)
      ab=${line#'# branch.ab '}
      ahead=${ab%% *}
      behind=${ab##* }
      ahead=${ahead#+}
      behind=${behind#-}
      ;;
    '1 '* | '2 '*)
      xy=${line#* }
      xy=${xy%% *}
      if [ "${xy:0:1}" != . ]; then staged=$((staged + 1)); fi
      if [ "${xy:1:1}" != . ]; then unstaged=$((unstaged + 1)); fi
      ;;
    'u '*) conflicts=$((conflicts + 1)) ;;
    '? '*) untracked=$((untracked + 1)) ;;
    esac
  done <<<"$gitout"
fi

# Detached HEAD reports the literal "(detached)" as the branch name; the short
# oid is the only useful identity in that state.
if [ "$branch" = '(detached)' ]; then
  branch="@${detached:0:7}"
fi

# ── meters ─────────────────────────────────────────────────────────────────
# FILLED and PACE are East-Asian-Ambiguous, EMPTY is Neutral, so a terminal
# configured to render ambiguous glyphs double-width draws a bar whose width
# changes with its fill. Harmless where ambiguous is narrow (ghostty's default);
# keep all three in one width class if these are ever swapped.
BAR_WIDTH=10
FILLED='▓'
EMPTY='░'
PACE='┃'

now=$(printf '%(%s)T' -1)

# heat VAR PCT — cyan at rest, escalating as the window fills.
heat() {
  local p=${2%%.*}
  if [ "${p:-0}" -ge 90 ]; then
    printf -v "$1" '%s' "$RED"
  elif [ "${p:-0}" -ge 70 ]; then
    printf -v "$1" '%s' "$ORG"
  else
    printf -v "$1" '%s' "$CYA"
  fi
}

# bar VAR PCT [PACE_PCT] — PACE_PCT marks where usage would be if the window
# were burned evenly, so fill left of the marker means ahead of pace.
bar() {
  local pct=${2%%.*} pace=${3:-} out='' i fill mark=-1
  pct=${pct:-0}
  [ "$pct" -gt 100 ] && pct=100
  fill=$((pct * BAR_WIDTH / 100))
  if [ -n "$pace" ]; then
    mark=$((${pace%%.*} * BAR_WIDTH / 100))
    [ "$mark" -ge "$BAR_WIDTH" ] && mark=$((BAR_WIDTH - 1))
  fi
  for ((i = 0; i < BAR_WIDTH; i++)); do
    if [ "$i" = "$mark" ]; then
      out+=$PACE
    elif [ "$i" -lt "$fill" ]; then
      out+=$FILLED
    else
      out+=$EMPTY
    fi
  done
  printf -v "$1" '%s' "$out"
}

# elapsed VAR RESETS_AT WINDOW_SECONDS — how far into the window we are, as a
# percentage, for the pacing marker.
elapsed() {
  local el=$((now - ($2 - $3)))
  [ "$el" -lt 0 ] && el=0
  [ "$el" -gt "$3" ] && el=$3
  printf -v "$1" '%d' $((el * 100 / $3))
}

# Reset time as a wall clock, not a countdown: something to plan around, and it
# does not churn on every render.
clock() {
  local t=$2
  if [ $((t - now)) -lt 43200 ]; then
    printf -v "$1" '%(%H:%M)T' "$t"
  else
    printf -v "$1" '%(%a %Hh)T' "$t"
  fi
}

# meter VAR LABEL PCT [RESETS_AT WINDOW_SECONDS]
meter() {
  local color b pace='' when='' tail=''
  heat color "$3"
  if [ -n "${4:-}" ]; then
    elapsed pace "$4" "$5"
    clock when "$4"
    tail=" ${DIM}⇥${when}${R}"
  fi
  bar b "$3" "$pace"
  # Literal gap before the width-3 percentage: %3d alone leaves none at 100 and
  # above, where the digits would touch the bar.
  printf -v "$1" '%s%s%s %s%s %3d%%%s%s' \
    "$DIM" "$2" "$R" "$color" "$b" "${3%%.*}" "$R" "$tail"
}

# ── line 1: identity ───────────────────────────────────────────────────────
[ -n "$repo" ] || repo=${cwd##*/}
line1="${BLU}${repo}${R}"

[ -n "$worktree" ] && line1+=" ${MAG}⧉ ${worktree}${R}"

if [ "$in_repo" = 1 ] && [ -n "$branch" ]; then
  line1+=" ${DIM}on${R} ${GRN}${branch}${R}"
  marks=''
  [ "$staged" -gt 0 ] && marks+=" ${GRN}+${staged}${R}"
  [ "$unstaged" -gt 0 ] && marks+=" ${YEL}~${unstaged}${R}"
  [ "$untracked" -gt 0 ] && marks+=" ${DIM}?${untracked}${R}"
  [ "$conflicts" -gt 0 ] && marks+=" ${RED}!${conflicts}${R}"
  [ "$ahead" -gt 0 ] && marks+=" ${CYA}↑${ahead}${R}"
  [ "$behind" -gt 0 ] && marks+=" ${RED}↓${behind}${R}"
  [ -n "$marks" ] && line1+="$marks" || line1+=" ${GRN}✓${R}"
fi

right="${MAG}${model}${R}"
[ -n "$effort" ] && right+=" ${DIM}·${R} ${MAG}${effort}${R}"
[ -n "$agent" ] && right+=" ${DIM}·${R} ${ORG}▸ ${agent}${R}"
[ -n "$ostyle" ] && [ "$ostyle" != default ] && right+=" ${DIM}·${R} ${DIM}✎ ${ostyle}${R}"

# ── line 2: meters ─────────────────────────────────────────────────────────
# A window is omitted rather than shown empty when its data is absent:
# rate_limits arrive only after the first API response, and never on API-key
# billing. A dim placeholder would be permanent dead space for those accounts.
m=''
line2=''
if [ -n "$ctx" ]; then
  meter m ctx "$ctx"
  line2+=$m
fi
if [ -n "$five" ] && [ -n "$five_at" ]; then
  meter m 5h "$five" "$five_at" 18000
  [ -n "$line2" ] && line2+='   '
  line2+=$m
fi
if [ -n "$seven" ] && [ -n "$seven_at" ]; then
  meter m 7d "$seven" "$seven_at" 604800
  [ -n "$line2" ] && line2+='   '
  line2+=$m
fi

printf '%s  %s│%s  %s\n' "$line1" "$DIM" "$R" "$right"
[ -n "$line2" ] && printf '%s\n' "$line2"

# Load-bearing under `errexit`: the line above is the last statement, and it
# exits non-zero whenever there are no meters to draw — an API-key account, or
# the first turns of a session before any window has data.
exit 0
