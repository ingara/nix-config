#!/usr/bin/env bash

set -euo pipefail

herdr_bin="${HERDR_BIN_PATH:-herdr}"
socket="${HERDR_SOCKET_PATH:?HERDR_SOCKET_PATH is required}"
state_dir="${HERDR_PLUGIN_STATE_DIR:?HERDR_PLUGIN_STATE_DIR is required}"
# Herdr's client waits for a reply without a deadline, so every call is bounded.
rpc_timeout=10
# A lock holder makes two bounded calls; this covers a short queue of them.
lock_wait=60

workspace_id="$(jq -r '.data.workspace.workspace_id // empty' <<<"${HERDR_PLUGIN_EVENT_JSON:-null}")"
[ -n "$workspace_id" ] || exit 0

# Herdr runs event hooks concurrently, so each read, decision and move happens
# under one lock per server; the state directory is shared by every server.
mkdir -p "$state_dir/locks"
exec 9>"$state_dir/locks/$(realpath -m -- "$socket" | cksum | cut -d ' ' -f 1).lock"
if ! flock -w "$lock_wait" 9; then
  printf 'workspace grouping lock wait timed out\n' >&2
  exit 1
fi

workspaces="$(timeout -k 2 "$rpc_timeout" "$herdr_bin" workspace list)"

# Only workspaces with worktree provenance carry a repository key; others stay
# put. The target is the repository's first contiguous run of other workspaces:
# a workspace already at either edge of it stays, any other moves to its end.
request="$(jq -c --arg id "$workspace_id" '
  .result.workspaces as $all
  | first(range($all | length) | select($all[.].workspace_id == $id)) as $index
  | ($all[$index].worktree.repo_key // "") as $key
  | select($key != "")
  | [$all[] | select(.workspace_id != $id)] as $others
  | first(range($others | length) | select($others[.].worktree.repo_key == $key)) as $start
  | (first(range($start; $others | length)
      | select($others[.].worktree.repo_key != $key)) // ($others | length)) as $after
  | select($all[$index + 1].workspace_id != $others[$start].workspace_id
      and ($index == 0 or $all[$index - 1].workspace_id != $others[$after - 1].workspace_id))
  | {
      id: "workspace-grouping",
      method: "workspace.move_block",
      params: ({workspace_ids: [$id]}
        + if $after < ($others | length)
          then {before_workspace_id: $others[$after].workspace_id}
          else {} end)
    }
' <<<"$workspaces")"
[ -n "$request" ] || exit 0

# The CLI has no move command; send one request over the socket API.
response="$(printf '%s\n' "$request" |
  timeout -k 2 "$rpc_timeout" socat -t "$rpc_timeout" - "UNIX-CONNECT:$socket")" || true
if ! jq -e '.result.type == "workspace_list"' <<<"$response" >/dev/null; then
  printf 'workspace.move_block failed: %s\n' "$response" >&2
  exit 1
fi
