#!/usr/bin/env bash

set -euo pipefail

display_bin="$1"
bash_bin="$2"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

export REPORT_LOG="$test_dir/reports"
export HERDR_BIN_PATH="$test_dir/herdr"
: >"$REPORT_LOG"

printf '#!%s\n' "$bash_bin" >"$HERDR_BIN_PATH"
cat >>"$HERDR_BIN_PATH" <<'EOF'
set -euo pipefail

case "$1:$2" in
  agent:get)
    case "$3" in
      named)
        printf '%s\n' '{"result":{"agent":{"agent":"claude","name":"review-lead","tokens":{}}}}'
        ;;
      unnamed)
        printf '%s\n' '{"result":{"agent":{"agent":"codex","tokens":{}}}}'
        ;;
      unchanged)
        printf '%s\n' '{"result":{"agent":{"agent":"claude","name":"reviewer","tokens":{"agent_display":"reviewer (claude)"}}}}'
        ;;
      no-agent)
        printf '%s\n' '{"result":{"agent":{"tokens":{}}}}'
        ;;
    esac
    ;;
  agent:list)
    printf '%s\n' '{"result":{"agents":[{"pane_id":"named"},{"pane_id":"unnamed"}]}}'
    ;;
  pane:report-metadata)
    printf '%s\n' "$*" >>"$REPORT_LOG"
    ;;
  *)
    exit 2
    ;;
esac
EOF
chmod +x "$HERDR_BIN_PATH"

"$display_bin" named
"$display_bin" unnamed
"$display_bin" unchanged
"$display_bin" no-agent

grep -Fx 'pane report-metadata named --source local.agent-display --agent claude --token agent_display=review-lead (claude)' "$REPORT_LOG"
grep -Fx 'pane report-metadata unnamed --source local.agent-display --agent codex --token agent_display=codex' "$REPORT_LOG"
[ "$(wc -l <"$REPORT_LOG")" -eq 2 ]

: >"$REPORT_LOG"
"$display_bin" --all
[ "$(wc -l <"$REPORT_LOG")" -eq 2 ]
