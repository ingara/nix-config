#!/usr/bin/env bash

set -euo pipefail

grouping_bin="$1"
bash_bin="$2"
# shellcheck source=herdr-workspace-repos-fixture.sh
source "$3"
test_dir="$(mktemp -d)"
server_log="$test_dir/server.log"
server_pid=""
# Every failure prints the fake server's log. A failure with the server gone is
# the environment's, not the plugin's: exit 75 (EX_TEMPFAIL) so the build reruns
# the fixtures.
cleanup() {
  local status=$? server_status=0
  if [ "$status" -ne 0 ] && [ -n "$server_pid" ]; then
    if kill -0 "$server_pid" 2>/dev/null; then
      printf 'The fake server is still running; its log follows.\n' >&2
    else
      wait "$server_pid" || server_status=$?
      printf 'The fake server exited with status %s; its log follows.\n' "$server_status" >&2
      status=75
    fi
    cat "$server_log" >&2
  fi
  if [ -n "$server_pid" ]; then
    kill "$server_pid" 2>/dev/null || true
  fi
  rm -rf "$test_dir"
  exit "$status"
}
trap cleanup EXIT

export REQUEST_LOG="$test_dir/requests"
export REJECT_FILE="$test_dir/reject"
export WORKSPACES_FILE="$test_dir/workspaces.json"
export HERDR_BIN_PATH="$test_dir/herdr"
export HERDR_SOCKET_PATH="$test_dir/herdr.sock"
export HERDR_PLUGIN_STATE_DIR="$test_dir/state"
: >"$REQUEST_LOG"

# The fake list answers with the order from before its delay, so hooks that
# overlap would act on a stale order.
printf '#!%s\n' "$bash_bin" >"$HERDR_BIN_PATH"
cat >>"$HERDR_BIN_PATH" <<'EOF'
set -euo pipefail
case "$1:$2" in
  api:snapshot)
    order="$(cat "$WORKSPACES_FILE")"
    sleep "${LIST_DELAY:-0}"
    printf '%s\n' "$order"
    ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$HERDR_BIN_PATH"

# Applies workspace.move_block to the fake list one request at a time, as Herdr does.
handler="$test_dir/handler"
printf '#!%s\n' "$bash_bin" >"$handler"
cat >>"$handler" <<'EOF'
set -euo pipefail
IFS= read -r line
exec 8>"$WORKSPACES_FILE.lock"
flock 8
printf '%s\n' "$line" >>"$REQUEST_LOG"
if [ -e "$REJECT_FILE" ]; then
  printf '%s\n' '{"id":"workspace-grouping","error":{"code":"workspace_not_found","message":"gone"}}'
  exit 0
fi
jq --argjson request "$line" '
  $request.params.workspace_ids as $ids
  | .result.snapshot.workspaces |= (
      map(select(.workspace_id as $id | $ids | index([$id]) | not)) as $rest
      | (first(range($rest | length)
          | select($rest[.].workspace_id == $request.params.before_workspace_id))
          // ($rest | length)) as $at
      | $rest[:$at] + map(select(.workspace_id as $id | $ids | index([$id]))) + $rest[$at:])
' "$WORKSPACES_FILE" >"$WORKSPACES_FILE.next"
mv "$WORKSPACES_FILE.next" "$WORKSPACES_FILE"
jq -c '{id: "workspace-grouping", result: {type:"workspace_list",workspaces:.result.snapshot.workspaces}}' "$WORKSPACES_FILE"
EOF
chmod +x "$handler"

socat -d -d "UNIX-LISTEN:$HERDR_SOCKET_PATH,fork" "EXEC:$handler" 2>"$server_log" &
server_pid=$!
# Ready once the server listens: a connection is queued before it is accepted.
# The probe sends no request.
ready_deadline=$((SECONDS + 30))
until socat -u /dev/null "UNIX-CONNECT:$HERDR_SOCKET_PATH" 2>/dev/null; do
  kill -0 "$server_pid" 2>/dev/null || exit 1
  if [ "$SECONDS" -ge "$ready_deadline" ]; then
    printf 'The fake server was not listening within 30 s.\n' >&2
    exit 1
  fi
  sleep 0.1
done

# Arguments: ordered "id:repo" entries, where an empty repo has no worktree.
workspaces() {
  : >"$REQUEST_LOG"
  jq -n --args '{result: {snapshot: {workspaces: [$ARGS.positional[]
    | split(":") as [$id, $repo]
    | {workspace_id: $id, label: $id}
      + if $repo == "" then {} else {worktree: {repo_key: "/src/\($repo)/.git", repo_name: $repo}} end],
    tabs:[],panes:[],layouts:[]}}}' \
    -- "$@" >"$WORKSPACES_FILE"
}

created() {
  HERDR_PLUGIN_EVENT=workspace.created \
    HERDR_PLUGIN_EVENT_JSON="$(jq -cn --arg id "$1" \
      '{event: "workspace.created", data: {type: "workspace_created", workspace: {workspace_id: $id}}}')" \
    "$grouping_bin"
}

# Hooks for workspaces created together run at once, as Herdr starts them.
# Arguments: "id:delay" pairs, the delay of that hook's workspace list.
created_together() {
  local -a pids=()
  local entry status=0
  for entry in "$@"; do
    LIST_DELAY="${entry#*:}" created "${entry%%:*}" &
    pids+=("$!")
  done
  # Every hook finishes before a failure is reported, so none outlives the fixtures.
  for pid in "${pids[@]}"; do
    wait "$pid" || status=$?
  done
  return "$status"
}

expect_order() {
  jq -e --arg expected "$*" '[.result.snapshot.workspaces[].workspace_id] | join(" ") == $expected' \
    "$WORKSPACES_FILE" >/dev/null
}

expect_requests() {
  jq -se --argjson expected "$1" '. == $expected' "$REQUEST_LOG" >/dev/null
}

# A new worktree joins the end of its repository's run, ahead of other repositories.
workspaces w1:alpha w2:alpha w3:beta w4: w5:alpha
created w5
expect_requests '[{"id": "workspace-grouping", "method": "workspace.move_block",
  "params": {"workspace_ids": ["w5"], "before_workspace_id": "w3"}}]'
expect_order w1 w2 w5 w3 w4

# With the run already at the end, the new workspace moves to the end.
workspaces w5:alpha w1:beta w2:alpha
created w5
expect_requests '[{"id": "workspace-grouping", "method": "workspace.move_block",
  "params": {"workspace_ids": ["w5"]}}]'
expect_order w1 w2 w5

# A fragmented repository gathers at its first run; later runs stay where they are.
workspaces a1:alpha b:beta a2:alpha n:alpha c:gamma
created n
expect_order a1 n b a2 c

expect_no_request() {
  created "$1"
  [ ! -s "$REQUEST_LOG" ]
}
# Already right after its repository's run.
workspaces w1:alpha w2:beta w3:beta
expect_no_request w3
# Already right before its repository's run.
workspaces w1:gamma w2:beta w3:beta w4:alpha
expect_no_request w2
# The only workspace of its repository.
workspaces w1:alpha w2:gamma w3:beta
expect_no_request w3
# An unresolvable generic workspace stays put.
workspaces w1:alpha w2: w3:alpha
expect_no_request w2
# Already closed again.
expect_no_request w9

# A worktree opened together with its parent checkout keeps the pair as it is.
workspaces w1:beta w2:alpha w3:alpha
created_together w2:0.3 w3:0.3
[ ! -s "$REQUEST_LOG" ]
expect_order w1 w2 w3

# Two new workspaces of one repository after an older run both join it.
workspaces a0:alpha b0:beta a1:alpha a2:alpha
created_together a1:0.3 a2:0.3
jq -e '[.result.snapshot.workspaces[] | .workspace_id] | .[0] == "a0" and .[3] == "b0"' \
  "$WORKSPACES_FILE" >/dev/null

# New workspaces of two repositories created together each join their own run.
# Without serialization, b1 would act on the order from before a1 moved.
workspaces a0:alpha b0:beta a1:alpha b1:beta
created_together a1:0.1 b1:0.6
expect_order a0 a1 b0 b1
ls "$HERDR_PLUGIN_STATE_DIR"/locks/*.lock >/dev/null

# Events without a workspace are ignored.
workspaces w1:alpha w2:alpha
HERDR_PLUGIN_EVENT_JSON='{"event":"workspace.created","data":{"type":"workspace_created"}}' \
  "$grouping_bin"
[ ! -s "$REQUEST_LOG" ]

# Creation-time grouping uses inferred identities for both the new workspace
# and the existing run. The first listed tab wins over stable tab numbers.
repo_fixture "$test_dir/git"
for id in linked duplicate; do
  cp "$test_dir/git/repos.json" "$WORKSPACES_FILE"
  : >"$REQUEST_LOG"
  created "$id"
  jq -e --arg id "$id" '
    [.result.snapshot.workspaces[].workspace_id] | .[0:3] == ["primary",$id,"plain"]
  ' "$WORKSPACES_FILE" >/dev/null
done
# With the explicit-worktree workspace removed, the inferred run still matches.
jq '.result.snapshot.workspaces |= (map(select(.workspace_id != "primary")) | .[1:2] + .[:1] + .[2:])' \
  "$test_dir/git/repos.json" >"$WORKSPACES_FILE"
: >"$REQUEST_LOG"
created linked
expect_order plain duplicate linked mixed missing bare unusual empty no-layout
expect_requests '[{"id":"workspace-grouping","method":"workspace.move_block",
  "params":{"workspace_ids":["linked"],"before_workspace_id":"mixed"}}]'
for id in mixed plain missing bare empty no-layout; do
  cp "$test_dir/git/repos.json" "$WORKSPACES_FILE"
  : >"$REQUEST_LOG"
  expect_no_request "$id"
done

# Failed or timed-out resolution must not move anything, even with a partial map.
printf '{"result":' >"$WORKSPACES_FILE"
: >"$REQUEST_LOG"
created linked 2>"$test_dir/invalid.stderr"
[ ! -s "$REQUEST_LOG" ]
grep -Fq linked "$test_dir/invalid.stderr"
cp "$test_dir/git/repos.json" "$WORKSPACES_FILE"
(
  git() { sleep 30; }
  export -f git
  export HERDR_PLUGIN_EVENT_JSON='{"data":{"workspace":{"workspace_id":"linked"}}}'
  timeout -k 2 15 "$grouping_bin"
) 2>"$test_dir/timeout.stderr"
[ ! -s "$REQUEST_LOG" ]
grep -Fq linked "$test_dir/timeout.stderr"
[ "$(wc -l <"$test_dir/timeout.stderr")" -eq 1 ]

# A rejected move fails the hook so Herdr records it in the plugin log.
touch "$REJECT_FILE"
workspaces w1:alpha w2:beta w3:alpha
if created w3 2>"$test_dir/stderr"; then
  exit 1
fi
grep -q 'workspace.move_block failed' "$test_dir/stderr"

printf 'Workspace grouping fixtures passed.\n'
