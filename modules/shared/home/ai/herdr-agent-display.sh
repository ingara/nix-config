#!/usr/bin/env bash

set -euo pipefail

herdr_bin="${HERDR_BIN_PATH:-herdr}"

refresh_agent() {
  local pane_id="$1"
  local info agent name current label

  if ! info="$("$herdr_bin" agent get "$pane_id" 2>/dev/null)"; then
    return 0
  fi

  agent="$(jq -r '.result.agent.agent // empty' <<<"$info")"
  [ -n "$agent" ] || return 0

  name="$(jq -r '.result.agent.name // empty' <<<"$info")"
  current="$(jq -r '.result.agent.tokens.agent_display // empty' <<<"$info")"
  if [ -n "$name" ]; then
    label="$name ($agent)"
  else
    label="$agent"
  fi

  [ "$current" = "$label" ] && return 0

  "$herdr_bin" pane report-metadata "$pane_id" \
    --source local.agent-display \
    --agent "$agent" \
    --token "agent_display=$label" >/dev/null
}

refresh_all() {
  local agents pane_id

  if ! agents="$("$herdr_bin" agent list 2>/dev/null)"; then
    return 0
  fi

  while IFS= read -r pane_id; do
    [ -n "$pane_id" ] && refresh_agent "$pane_id" || true
  done < <(jq -r '.result.agents[]?.pane_id // empty' <<<"$agents")
}

case "${1:-}" in
--all)
  refresh_all
  ;;
"")
  [ -n "${HERDR_PANE_ID:-}" ] && refresh_agent "$HERDR_PANE_ID"
  ;;
*)
  refresh_agent "$1"
  ;;
esac
