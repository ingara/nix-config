#!/usr/bin/env bash
# Claude Code statusLine renderer.
#
# Reads the statusLine JSON payload on stdin and prints two lines sized to the
# pane:
#
#   repo [⧉ worktree] [on branch] <status>                 Model · effort   #123 ●   +128 −34
#   ctx ━━━━━━──────  47% │ 5h ━━━┃━────  32% ⇥14:22 │ 7d ━━──┃────  18% ⇥Tue 09h
#
# Line 1 is identity on the left and session facts right-aligned: model and
# effort (and agent, if any), the branch's pull request with its review state,
# and lines changed. Line 2 is the meters in equal columns whose bars stretch
# with the pane.
#
# Claude Code passes the pane width in COLUMNS, and a line must stay four
# columns narrower than that. When it does not fit, session facts drop from the
# right (lines, pull request, then model), then bars shrink, then reset times
# go, then meters fall back to bare numbers. Identity is cut, with an ellipsis,
# only when it alone is too wide.
#
# Everything comes from the payload, plus one `git status` for branch and
# working-tree state.
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

# Braced so a NUL byte's "ignored null byte" warning goes nowhere.
{ blob=$(cat); } 2>/dev/null

if [ -n "${CLAUDE_STATUSLINE_DEBUG:-}" ]; then
  printf '%s' "$blob" >"$CLAUDE_STATUSLINE_DEBUG" || true
fi

# ── palette ────────────────────────────────────────────────────────────────
# Base16 slots, overridable from a theme file. The defaults apply when that
# file is absent.
base03=6e6a86 # faint  — empty bar, column rules
base04=908caa # muted  — labels, separators
base05=e0def4 # text   — pace tick
base08=eb6f92 # red    — over budget, behind upstream, conflicts
base09=f6c177 # orange — approaching budget, agent
base0A=f6c177 # yellow — unstaged, review pending
base0B=31748f # green  — branch, staged, clean
base0C=9ccfd8 # cyan   — meters at rest, ahead of upstream
base0D=3e8fb0 # blue   — repo, pull request
base0E=c4a7e7 # magenta— model, worktree

theme="${XDG_CONFIG_HOME:-${HOME:-}/.config}/claude-statusline/theme.env"
if [ -f "$theme" ] && [ -r "$theme" ]; then
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
setcolor FNT "$base03"
setcolor DIM "$base04"
setcolor TXT "$base05"
setcolor RED "$base08"
setcolor ORG "$base09"
setcolor YEL "$base0A"
setcolor GRN "$base0B"
setcolor CYA "$base0C"
setcolor BLU "$base0D"
setcolor MAG "$base0E"
R=$'\e[0m'

# ── width ──────────────────────────────────────────────────────────────────
# 80 when COLUMNS is absent or zero, as when the script is run by hand;
# capped, because the bars are drawn a cell at a time.
cols=${COLUMNS:-}
case $cols in *[!0-9]*) cols='' ;; esac
while [ "${cols#0}" != "$cols" ]; do cols=${cols#0}; done
[ -n "$cols" ] || cols=80
[ "${#cols}" -le 4 ] && [ "$cols" -le 1000 ] || cols=1000
max=$((cols - 4))
[ "$max" -ge 1 ] || max=1

# Widths are counted in characters. Outside a UTF-8 locale ${#var} counts
# bytes, so switch to one if the system has one; failing that, count only the
# bytes that start a character. Braced, because a failed LC_ALL assignment
# warns on stderr.
probe='━'
if [ "${#probe}" != 1 ]; then
  lc_was=${LC_ALL-unset}
  for loc in C.UTF-8 en_US.UTF-8; do
    { LC_ALL=$loc; } 2>/dev/null
    [ "${#probe}" != 1 ] || break
  done
  if [ "${#probe}" != 1 ]; then
    if [ "$lc_was" = unset ]; then unset LC_ALL; else { LC_ALL=$lc_was; } 2>/dev/null; fi
  fi
fi
u8=0
[ "${#probe}" != 1 ] || u8=1
cont=$'[\x80-\xbf]'

# cw VAR TEXT — TEXT's width in characters.
cw() {
  if [ "$u8" = 1 ]; then
    printf -v "$1" '%d' "${#2}"
  else
    local s=${2//$cont/}
    printf -v "$1" '%d' "${#s}"
  fi
}

# clip VAR TEXT N — the first N characters of TEXT.
clip() {
  if [ "$u8" = 1 ]; then
    printf -v "$1" '%s' "${2:0:$3}"
    return
  fi
  local i=0 n=0
  while [ "$i" -lt "${#2}" ]; do
    # shellcheck disable=SC2254 # $cont is a byte-range pattern
    case ${2:i:1} in
    $cont) ;;
    *)
      [ "$n" -lt "$3" ] || break
      n=$((n + 1))
      ;;
    esac
    i=$((i + 1))
  done
  printf -v "$1" '%s' "${2:0:i}"
}

# ── payload ────────────────────────────────────────────────────────────────
# Unit separator, not @tsv: tab is IFS whitespace, so bash would collapse runs
# of it and every absent field would shift the rest of the assignment left.
#
# Every field feeding arithmetic goes through `int`, which yields nothing for
# anything non-numeric or NaN and clamps the rest, so it arrives as either the
# empty string the guards below already handle or a plain integer. This is an
# unversioned contract we do not control, and a string reaching `$(( ))` is
# fatal under `nounset` — it takes the whole line down, not just one field.
#
# The payload reaches jq as raw text on stdin and is parsed inside jq, so
# malformed input yields empty fields rather than a jq error. The separator reaches jq as --arg rather than as a
# \u001f escape in the program text: rendering tools can rewrite \uXXXX into
# the literal control byte (`gh gist view` does), which jq rejects at compile
# time.
us=$'\x1f'
# shellcheck disable=SC2016 # jq program, not shell expansions
prog='
  def int($lo; $hi): tonumber? | select(. == .)
    | if . < $lo then $lo elif . > $hi then $hi else . end | floor;
  (try fromjson catch {} | if type == "object" then . else {} end)
  | [ ((.workspace.repo.name)?            // ""),
      ((.workspace.git_worktree)? // (.worktree.name)? // ""),
      ((.workspace.current_dir)?         // .cwd? // ""),
      ((.model.display_name)?             // ""),
      ((.effort.level)?                   // ""),
      ((.agent.name)?                     // ""),
      ((.context_window.used_percentage)?        | int(0; 999) // ""),
      ((.rate_limits.five_hour.used_percentage)? | int(0; 999) // ""),
      ((.rate_limits.five_hour.resets_at)?       | int(0; 1e10) // ""),
      ((.rate_limits.seven_day.used_percentage)? | int(0; 999) // ""),
      ((.rate_limits.seven_day.resets_at)?       | int(0; 1e10) // ""),
      ((.pr.number)?                             | int(0; 1e9) // ""),
      ((.pr.review_state)?                // ""),
      ((.cost.total_lines_added)?                | int(0; 1e9) // ""),
      ((.cost.total_lines_removed)?              | int(0; 1e9) // "")
    ] | map(tostring | gsub("[\n\r]"; " ") | split($us) | join(" ")) | join($us)'

IFS=$us read -r repo worktree cwd model effort agent ctx five five_at seven seven_at \
  pr_num pr_state added removed <<<"$(printf '%s' "$blob" | jq -R -s -r --arg us "$us" "$prog")"

[ -n "$cwd" ] || cwd=$PWD

now=$(printf '%(%s)T' -1)

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

# ── layout ─────────────────────────────────────────────────────────────────
# A line is queued as parts (colour, text) so it can be measured and, if need
# be, cut. Width is the character count: every glyph this script draws is one column,
# though most are East-Asian-Ambiguous, so a terminal that draws ambiguous
# glyphs double-width will overflow. Text from the payload or git (names,
# branches) is assumed to be one column per character.
PC=() PT=()
part() {
  PC+=("$1")
  PT+=("$2")
}

# flush VAR LIMIT — render the queued parts into VAR, cut to LIMIT columns with
# an ellipsis, and clear the queue.
flush() {
  local out='' w=0 i t tw total=0 lim=$2
  if [ "${#PT[@]}" -gt 0 ]; then
    for t in "${PT[@]}"; do
      cw tw "$t"
      total=$((total + tw))
    done
    [ "$total" -le "$lim" ] || lim=$(($2 - 1))
    for i in "${!PT[@]}"; do
      t=${PT[i]}
      cw tw "$t"
      if [ $((w + tw)) -gt "$lim" ]; then
        clip t "$t" $((lim - w))
        out+="${PC[i]}${t}${R}${DIM}…${R}"
        break
      fi
      if [ -n "${PC[i]}" ]; then out+="${PC[i]}${t}${R}"; else out+=$t; fi
      w=$((w + tw))
    done
  fi
  printf -v "$1" '%s' "$out"
  PC=() PT=()
}

# ── line 1: identity and session facts ─────────────────────────────────────
gitmark() {
  part '' ' '
  part "$1" "$2"
}

[ -n "$repo" ] || repo=${cwd##*/}
part "$BLU" "$repo"

if [ -n "$worktree" ]; then
  part '' ' '
  part "$MAG" "⧉ $worktree"
fi

if [ "$in_repo" = 1 ] && [ -n "$branch" ]; then
  # A worktree named after its branch would say the name twice.
  if [ "$branch" != "$worktree" ]; then
    part '' ' '
    part "$DIM" on
    part '' ' '
    part "$GRN" "$branch"
  fi
  nparts=${#PT[@]}
  [ "$staged" -gt 0 ] && gitmark "$GRN" "+$staged"
  [ "$unstaged" -gt 0 ] && gitmark "$YEL" "~$unstaged"
  [ "$untracked" -gt 0 ] && gitmark "$DIM" "?$untracked"
  [ "$conflicts" -gt 0 ] && gitmark "$RED" "!$conflicts"
  [ "$ahead" -gt 0 ] && gitmark "$CYA" "↑$ahead"
  [ "$behind" -gt 0 ] && gitmark "$RED" "↓$behind"
  [ "${#PT[@]}" -gt "$nparts" ] || gitmark "$GRN" ✓
fi

idw=0
for t in "${PT[@]}"; do
  cw w "$t"
  idw=$((idw + w))
done

# Display order is drop order: a narrow pane keeps a prefix of these.
FS=() FW=()
fact() {
  FS+=("$1")
  FW+=("$2")
}
if [ -n "$model" ]; then
  t="${MAG}${model}${R}"
  cw w "$model"
  if [ -n "$effort" ]; then
    t+=" ${DIM}·${R} ${MAG}${effort}${R}"
    cw c "$effort"
    w=$((w + 3 + c))
  fi
  if [ -n "$agent" ]; then
    t+=" ${DIM}·${R} ${ORG}▸ ${agent}${R}"
    cw c "$agent"
    w=$((w + 5 + c))
  fi
  fact "$t" "$w"
fi
if [ -n "$pr_num" ]; then
  case $pr_state in
  approved) t=" ${GRN}✓${R}" ;;
  pending) t=" ${YEL}●${R}" ;;
  changes_requested) t=" ${RED}✗${R}" ;;
  draft) t=" ${DIM}◌${R}" ;;
  *) t='' ;;
  esac
  w=$((1 + ${#pr_num}))
  [ -z "$t" ] || w=$((w + 2))
  fact "${BLU}#${pr_num}${R}${t}" "$w"
fi
added=${added:-0} removed=${removed:-0}
if [ "$added" -gt 0 ] || [ "$removed" -gt 0 ]; then
  fact "${GRN}+${added}${R} ${RED}−${removed}${R}" $((3 + ${#added} + ${#removed}))
fi

n=${#FS[@]}
rw=0
while [ "$n" -gt 0 ]; do
  rw=0
  for ((i = 0; i < n; i++)); do rw=$((rw + FW[i])); done
  rw=$((rw + 3 * (n - 1)))
  [ $((idw + 2 + rw)) -le "$max" ] && break
  n=$((n - 1))
done

flush line1 "$max"
if [ "$n" -gt 0 ]; then
  printf -v pad '%*s' $((max - idw - rw)) ''
  line1+=$pad
  for ((i = 0; i < n; i++)); do
    [ "$i" = 0 ] || line1+='   '
    line1+=${FS[i]}
  done
fi

# ── line 2: meters ─────────────────────────────────────────────────────────
# A window is omitted rather than shown empty when its data is absent:
# rate_limits arrive only after the first API response, and never on API-key
# billing. A dim placeholder would be permanent dead space for those accounts.

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

ML=() MP=() MK=() MZ=()
gauge() {
  local pace='' when=''
  if [ -n "${3:-}" ]; then
    elapsed pace "$3" "$4"
    clock when "$3"
    when="⇥$when"
  fi
  ML+=("$1")
  MP+=("$2")
  MK+=("$pace")
  MZ+=("$when")
}
[ -z "$ctx" ] || gauge ctx "$ctx"
[ -z "$five" ] || [ -z "$five_at" ] || gauge 5h "$five" "$five_at" 18000
[ -z "$seven" ] || [ -z "$seven_at" ] || gauge 7d "$seven" "$seven_at" 604800

# barlen VAR I RESETS — the bar length that fills meter I's column: the column
# less label, two spaces, percentage and, with RESETS, the reset time.
barlen() {
  local len=$((colw - ${#ML[$2]} - 6)) z
  cw z "${MZ[$2]}"
  [ "$3" = 0 ] || [ -z "${MZ[$2]}" ] || len=$((len - 1 - z))
  printf -v "$1" '%d' "$len"
}

# barw VAR RESETS — the shortest bar among the meters, with or without reset
# times.
barw() {
  local i w narrowest=''
  for i in "${!ML[@]}"; do
    barlen w "$i" "$2"
    [ -n "$narrowest" ] && [ "$narrowest" -le "$w" ] || narrowest=$w
  done
  printf -v "$1" '%d' "$narrowest"
}

# FILLED, EMPTY and TICK are box drawing, so they share one East Asian width
# class and a bar keeps its width whatever its fill.
FILLED='━'
EMPTY='─'
TICK='┃'
MIN_BAR=4

# meter I BARS RESETS — queue meter I, its bar stretched to fill the column.
meter() {
  local i=$1 color pct=${MP[$1]} w mark=-1 fill j cls prev='' run='' c start
  heat color "$pct"
  start=${#PT[@]}
  part "$DIM" "${ML[i]}"
  part '' ' '
  if [ "$2" = 1 ]; then
    barlen w "$i" "$3"
    fill=$pct
    [ "$fill" -le 100 ] || fill=100
    [ "$fill" -ge 0 ] || fill=0
    fill=$((fill * w / 100))
    if [ -n "${MK[i]}" ]; then
      mark=$((MK[i] * w / 100))
      [ "$mark" -lt "$w" ] || mark=$((w - 1))
    fi
    for ((j = 0; j <= w; j++)); do
      if [ "$j" = "$w" ]; then
        cls=end
      elif [ "$j" = "$mark" ]; then
        cls=tick
      elif [ "$j" -lt "$fill" ]; then
        cls=fill
      else
        cls=empty
      fi
      if [ "$cls" != "$prev" ] && [ -n "$run" ]; then
        case $prev in tick) c=$TXT ;; fill) c=$color ;; *) c=$FNT ;; esac
        part "$c" "$run"
        run=''
      fi
      case $cls in tick) run+=$TICK ;; fill) run+=$FILLED ;; empty) run+=$EMPTY ;; esac
      prev=$cls
    done
    part '' ' '
  fi
  # %3d: the percentage keeps its width from 0 to 100.
  printf -v c '%3d%%' "$pct"
  part "$color" "$c"
  if [ "$3" = 1 ] && [ -n "${MZ[i]}" ]; then
    part '' ' '
    part "$DIM" "${MZ[i]}"
  fi
  mw=0
  for ((j = start; j < ${#PT[@]}; j++)); do
    cw c "${PT[j]}"
    mw=$((mw + c))
  done
}

line2=''
k=${#ML[@]}
if [ "$k" -gt 0 ]; then
  colw=$(((max - 3 * (k - 1)) / k))
  bars=1 resets=1 low=0
  barw low 1
  if [ "$low" -lt "$MIN_BAR" ]; then
    resets=0
    barw low 0
    [ "$low" -ge "$MIN_BAR" ] || bars=0
  fi
  for ((m = 0; m < k; m++)); do
    if [ "$m" -gt 0 ]; then
      part '' ' '
      part "$FNT" '│'
      part '' ' '
    fi
    meter "$m" "$bars" "$resets"
    if [ $((m + 1)) -lt "$k" ] && [ "$mw" -lt "$colw" ]; then
      printf -v pad '%*s' $((colw - mw)) ''
      part '' "$pad"
    fi
  done
  flush line2 "$max"
fi

printf '%s\n' "$line1"
[ -n "$line2" ] && printf '%s\n' "$line2"

# Load-bearing under `errexit`: the line above is the last statement, and it
# exits non-zero whenever there are no meters to draw — an API-key account, or
# the first turns of a session before any window has data.
exit 0
