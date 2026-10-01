# shellcheck shell=bash
# Sourced into the Nix-generated wm-switch command after ENABLED and APP arrays.
# lockf serializes the login agent with manual switches; its lock is released even
# if the process dies, unlike a mkdir/PID lock.
if [ "${1:-}" != --locked ]; then
  if [ "$#" -ne 1 ]; then
    echo "usage: wm-switch <${ENABLED[*]}>" >&2
    exit 2
  fi
  /bin/mkdir -p "$HOME/.local/state"
  exec /usr/bin/lockf -t 120 "$HOME/.local/state/wm-switch.lock" "$0" --locked "$1"
fi
shift
if [ "$#" -ne 1 ]; then
  echo "usage: wm-switch <${ENABLED[*]}>" >&2
  exit 2
fi
target=$1
in_enabled=0
for w in "${ENABLED[@]}"; do
  if [ "$w" = "$target" ]; then in_enabled=1; fi
done
if [ "$in_enabled" -ne 1 ]; then
  echo "wm-switch: '$target' not in switchable set (${ENABLED[*]})" >&2
  exit 1
fi

app_path() { printf '/Applications/%s.app' "${APP[$1]}"; }
app_state() {
  local state status
  if [ ! -d "$(app_path "$1")" ]; then
    # A removed cask can leave a process resident during activation. Do not
    # launch another manager if LaunchServices can no longer quit that app.
    if /usr/bin/pgrep -x "${APP[$1]}" >/dev/null 2>&1; then
      echo "wm-switch: ${APP[$1]} is running without its app bundle; quit it before switching" >&2
      return 1
    else
      status=$?
      if [ "$status" -ne 1 ]; then
        echo "wm-switch: could not check for ${APP[$1]}" >&2
        return 1
      fi
    fi
    printf 'false\n'
    return 0
  fi
  state=$(/usr/bin/osascript -e "application \"${APP[$1]}\" is running") || return 1
  case "$state" in
  true | false) printf '%s\n' "$state" ;;
  *)
    echo "wm-switch: unexpected application state for ${APP[$1]}: $state" >&2
    return 1
    ;;
  esac
}
wait_state() {
  local w=$1 expected=$2 state
  for ((i = 0; i < 120; i++)); do
    state=$(app_state "$w") || return 1
    if [ "$state" = "$expected" ]; then return 0; fi
    /bin/sleep 0.25
  done
  echo "wm-switch: timed out waiting for ${APP[$w]} to become $expected" >&2
  return 1
}
stop_app() {
  local w=$1 state
  state=$(app_state "$w") || return 1
  if [ "$state" = false ]; then return 0; fi
  /usr/bin/osascript -e "if application \"${APP[$w]}\" is running then tell application \"${APP[$w]}\" to quit" || return 1
  wait_state "$w" false
}
start_app() {
  local w=$1 state
  state=$(app_state "$w") || return 1
  if [ "$state" = false ]; then
    /usr/bin/open -a "$(app_path "$w")" || return 1
  fi
  wait_state "$w" true || return 1
  # Running status alone does not prove IPC is ready. Neither this probe nor
  # open can prove actual tiling; that needs a supervised live window check.
  for ((i = 0; i < 120; i++)); do
    if [ "$w" = omniwm ]; then
      if /Applications/OmniWM.app/Contents/MacOS/omniwmctl ping >/dev/null 2>&1; then return 0; fi
    elif /Applications/Nehir.app/Contents/MacOS/nehirctl query windows --format json >/dev/null 2>&1; then
      return 0
    fi
    state=$(app_state "$w") || return 1
    if [ "$state" = false ]; then break; fi
    /bin/sleep 0.25
  done
  echo "wm-switch: ${APP[$w]} did not become IPC-ready (check config/permissions)" >&2
  return 1
}

skhd_dir="$HOME/.config/skhd"
layer="$skhd_dir/active-wm.skhd"
set_layer() {
  local w=$1 tmpdir
  /bin/mkdir -p "$skhd_dir"
  tmpdir=$(/usr/bin/mktemp -d "$skhd_dir/.active-wm.XXXXXXXX") || return 1
  if [ -n "$w" ]; then
    if [ ! -f "$skhd_dir/$w.skhd" ]; then
      echo "wm-switch: missing $skhd_dir/$w.skhd" >&2
      /bin/rmdir "$tmpdir"
      return 1
    fi
    /bin/ln -s "$skhd_dir/$w.skhd" "$tmpdir/active-wm.skhd" || return 1
  else
    /usr/bin/printf '# no active WM-specific bindings\n' >"$tmpdir/active-wm.skhd" || return 1
  fi
  /bin/mv -f "$tmpdir/active-wm.skhd" "$layer" || return 1
  /bin/rmdir "$tmpdir"
}
reload_skhd() {
  local label
  label="gui/$(/usr/bin/id -u)/com.jackielii.skhd"
  if /bin/launchctl print "$label" >/dev/null 2>&1; then
    /bin/launchctl kickstart -k "$label"
  else
    echo 'wm-switch: skhd agent not loaded; selected layer will load when skhd starts' >&2
  fi
}

# A failed launch must never start the old WM alongside a partial new launch.
# Even errors in skhd reloading take this recovery path.
previous=
target_was_running=0
transition=0
recover() {
  local status=$? restore_layer=$previous
  trap - EXIT
  if [ "$status" -ne 0 ] && [ "$transition" -eq 1 ]; then
    if [ "$target_was_running" -eq 1 ] && [ -z "$previous" ]; then
      # A failed refresh of the sole running manager must not shut it down.
      restore_layer=$target
    else
      if ! stop_app "$target"; then
        echo "wm-switch: cannot restore ${previous:-previous manager}: $target is still running" >&2
        exit 1
      fi
      if [ -n "$previous" ] && ! start_app "$previous"; then
        echo "wm-switch: could not restart $previous" >&2
        exit 1
      fi
    fi
    if ! set_layer "$restore_layer" || ! reload_skhd; then
      echo 'wm-switch: could not restore skhd layer' >&2
      exit 1
    fi
    echo "wm-switch: switch to $target failed; restored ${restore_layer:-no manager}" >&2
  fi
  exit "$status"
}
trap recover EXIT

# Preflight before quitting anything; resolve the exact cask path rather than
# LaunchServices' possibly stale registration for an app with the same name.
app=$(app_path "$target")
if [ ! -d "$app" ] || [ ! -f "$app/Contents/Info.plist" ]; then
  echo "wm-switch: missing app bundle: $app" >&2
  exit 1
fi
cli="$app/Contents/MacOS/$target"ctl
if [ ! -x "$cli" ]; then
  echo "wm-switch: missing bundled CLI: $cli" >&2
  exit 1
fi
state=$(app_state "$target") || exit 1
if [ "$state" = true ]; then target_was_running=1; fi
for w in "${KNOWN[@]}"; do
  if [ "$w" != "$target" ]; then
    state=$(app_state "$w") || exit 1
    if [ "$state" = true ]; then previous=$w; fi
  fi
done
# Verify the layer exists before tearing down the running manager.
if [ ! -f "$skhd_dir/$target.skhd" ]; then
  echo "wm-switch: missing $skhd_dir/$target.skhd" >&2
  exit 1
fi
transition=1
set_layer ''
reload_skhd
for w in "${KNOWN[@]}"; do
  if [ "$w" != "$target" ]; then stop_app "$w"; fi
done
start_app "$target"
# Login items can start independently of this script; never report a
# successful switch if the other manager resurfaced during target startup.
for w in "${KNOWN[@]}"; do
  if [ "$w" != "$target" ]; then
    state=$(app_state "$w") || exit 1
    if [ "$state" = true ]; then
      echo "wm-switch: ${APP[$w]} restarted during switch" >&2
      exit 1
    fi
  fi
done
set_layer "$target"
reload_skhd
transition=0
echo "wm-switch: $target running (IPC ready; verify window management live)"
