#!/usr/bin/env bash

set -euo pipefail

grouping_bin="$1"
bash_bin="$2"
test_dir="$(mktemp -d)"
server_pid=""
cleanup() {
  if [ -n "$server_pid" ]; then
    kill "$server_pid" 2>/dev/null || true
  fi
  rm -rf "$test_dir"
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
  workspace:list)
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
  | .result.workspaces |= (
      map(select(.workspace_id as $id | $ids | index([$id]) | not)) as $rest
      | (first(range($rest | length)
          | select($rest[.].workspace_id == $request.params.before_workspace_id))
          // ($rest | length)) as $at
      | $rest[:$at] + map(select(.workspace_id as $id | $ids | index([$id]))) + $rest[$at:])
' "$WORKSPACES_FILE" >"$WORKSPACES_FILE.next"
mv "$WORKSPACES_FILE.next" "$WORKSPACES_FILE"
jq -c '{id: "workspace-grouping", result: .result}' "$WORKSPACES_FILE"
EOF
chmod +x "$handler"

socat "UNIX-LISTEN:$HERDR_SOCKET_PATH,fork" "EXEC:$handler" 2>/dev/null &
server_pid=$!
for _ in $(seq 50); do
  [ -S "$HERDR_SOCKET_PATH" ] && break
  sleep 0.1
done

# Arguments: ordered "id:repo" entries, where an empty repo has no worktree.
workspaces() {
  : >"$REQUEST_LOG"
  jq -n --args '{result: {type: "workspace_list", workspaces: [$ARGS.positional[]
    | split(":") as [$id, $repo]
    | {workspace_id: $id, label: $id}
      + if $repo == "" then {} else {worktree: {repo_key: "/src/\($repo)/.git", repo_name: $repo}} end]}}' \
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
  local entry
  for entry in "$@"; do
    LIST_DELAY="${entry#*:}" created "${entry%%:*}" &
    pids+=("$!")
  done
  for pid in "${pids[@]}"; do
    wait "$pid"
  done
}

expect_order() {
  jq -e --arg expected "$*" '[.result.workspaces[].workspace_id] | join(" ") == $expected' \
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
# Without worktree provenance.
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
jq -e '[.result.workspaces[] | .workspace_id] | .[0] == "a0" and .[3] == "b0"' \
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

# A rejected move fails the hook so Herdr records it in the plugin log.
touch "$REJECT_FILE"
workspaces w1:alpha w2:beta w3:alpha
if created w3 2>"$test_dir/stderr"; then
  exit 1
fi
grep -q 'workspace.move_block failed' "$test_dir/stderr"

printf 'Workspace grouping fixtures passed.\n'
