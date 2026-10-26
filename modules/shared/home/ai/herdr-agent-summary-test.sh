#!/usr/bin/env bash

set -euo pipefail

summary_bin="$1"
bash_bin="$2"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

export HERDR_BIN_PATH="$test_dir/herdr"
export HERDR_PLUGIN_STATE_DIR="$test_dir/state"
export HERDR_AGENT_SUMMARY_CLAUDE="$test_dir/claude"
export HERDR_AGENT_SUMMARY_CLAUDE_CONFIG_DIR="$test_dir/claude-config"
export HERDR_AGENT_SUMMARY_WORKER_PREFIXES='["worker-"]'
export HERDR_AGENT_SUMMARY_INTERVAL=1
export HERDR_AGENT_SUMMARY_SETTLE=0
export PI_CODING_AGENT_DIR="$test_dir/omp"
export AGENTS_DIR="$test_dir/agents"
export REPORT_LOG="$test_dir/reports"
export CLAUDE_LOG="$test_dir/claude-calls"
export CLAUDE_MODE="$test_dir/claude-mode"
export HANG_FILE="$test_dir/hang"
export BARRIER_DIR="$test_dir/barrier"
export SNAPSHOT_BARRIER="$test_dir/snapshot-barrier"
# Inherited plugin context that must not reach the summariser.
export HERDR_PANE_ID=focused HERDR_ENV=1 HERDR_SOCKET_PATH="$test_dir/sock" CLAUDECODE=1

ns_dir="$HERDR_PLUGIN_STATE_DIR/servers/$(realpath -m -- "$HERDR_SOCKET_PATH" | cksum | cut -d ' ' -f 1)"
model_lock="$ns_dir/locks/lead.model"

mkdir -p "$AGENTS_DIR" "$HERDR_PLUGIN_STATE_DIR" \
  "$test_dir/claude-config/projects/-repo" "$test_dir/omp/sessions/-repo" "$test_dir/elsewhere"
: >"$REPORT_LOG"
: >"$CLAUDE_LOG"

printf '#!%s\n' "$bash_bin" >"$HERDR_BIN_PATH"
cat >>"$HERDR_BIN_PATH" <<'EOF'
set -euo pipefail
# A server that accepts requests and never replies.
if [ -e "$HANG_FILE" ]; then
  sleep 300
fi
case "$1:$2" in
  agent:get)
    [ -f "$AGENTS_DIR/$3.json" ] || { echo '{"error":{"code":"agent_not_found"}}' >&2; exit 1; }
    jq -c '{id: "cli:agent:get", result: {type: "agent", agent: .}}' "$AGENTS_DIR/$3.json"
    ;;
  api:snapshot)
    snapshot="$(jq -sc '{result: {snapshot: {agents: .}}}' "$AGENTS_DIR"/*.json)"
    # One snapshot is held after capture, so the world can change before it lands.
    if [ -e "$SNAPSHOT_BARRIER" ]; then
      rm -f "$SNAPSHOT_BARRIER"
      : >"$SNAPSHOT_BARRIER.ready"
      until [ -e "$SNAPSHOT_BARRIER.release" ]; do sleep 0.05; done
    fi
    printf '%s\n' "$snapshot"
    ;;
  pane:report-metadata)
    jq -cn --args '$ARGS.positional' -- "$@" >>"$REPORT_LOG"
    ;;
  *)
    exit 2
    ;;
esac
EOF
chmod +x "$HERDR_BIN_PATH"

printf '#!%s\n' "$bash_bin" >"$HERDR_AGENT_SUMMARY_CLAUDE"
cat >>"$HERDR_AGENT_SUMMARY_CLAUDE" <<'EOF'
set -euo pipefail
input="$(cat)"
jq -cn --arg cwd "$PWD" --arg input "$input" --arg config "${CLAUDE_CONFIG_DIR:-}" \
  --arg inherited "$(env | grep -E '^(HERDR_|CLAUDECODE=)' || true)" \
  '{args: $ARGS.positional, cwd: $cwd, input: $input, config: $config, inherited: $inherited}' \
  --args -- "$@" >>"$CLAUDE_LOG"
mode="$(cat "$CLAUDE_MODE")"
case "$mode" in
  fail) echo "Invalid API key" ; exit 1 ;;
  error) jq -cn '{type: "result", is_error: true, result: "Credit balance is too low"}' ;;
  slow) sleep 300 ;;
  barrier)
    : >"$BARRIER_DIR/called"
    until [ -e "$BARRIER_DIR/release" ]; do sleep 0.05; done
    jq -cn '{type: "result", is_error: false, result: "Old lead task"}'
    ;;
  *) jq -cn --arg result "$mode" '{type: "result", is_error: false, result: $result}' ;;
esac
EOF
chmod +x "$HERDR_AGENT_SUMMARY_CLAUDE"

claude_transcript="$test_dir/claude-config/projects/-repo/c0ffee-1.jsonl"
omp_transcript="$test_dir/omp/sessions/-repo/2026_omp.jsonl"

agent() {
  # pane agent name status session-json [tokens-json]
  jq -n --arg pane "$1" --arg agent "$2" --arg name "$3" --arg status "$4" \
    --argjson session "$5" --argjson tokens "${6:-null}" \
    '{pane_id: $pane, agent: $agent, name: $name, agent_status: $status,
      agent_session: $session, tokens: ($tokens // {})}' >"$AGENTS_DIR/$1.json"
}
claude_session='{"agent":"claude","kind":"id","source":"herdr:claude","value":"c0ffee-1"}'
omp_session="$(jq -cn --arg path "$omp_transcript" '{agent: "omp", kind: "path", value: $path}')"

calls() { wc -l <"$CLAUDE_LOG" | tr -d ' '; }
reports() {
  jq -sc 'map(. as $args | {
    pane: .[2], source: .[4], agent: .[6],
    tokens: (reduce range(9; length; 2) as $i ({};
      if $args[$i] == "--token"
      then ($args[$i + 1] | index("=")) as $eq
        | . + {($args[$i + 1][0:$eq]): $args[$i + 1][$eq + 1:]}
      else . + {($args[$i + 1]): null} end))
  })' "$REPORT_LOG"
}
last_report() { reports | jq -c 'last'; }
wait_for() {
  local deadline=$((SECONDS + 60))
  until eval "$1"; do
    [ "$SECONDS" -lt "$deadline" ] || {
      echo "timed out waiting for: $1" >&2
      exit 1
    }
    sleep 0.2
  done
}

# --- Transcript digests -------------------------------------------------------

cat >"$claude_transcript" <<'EOF'
{"type":"user","message":{"role":"user","content":"Add retry to the login client"}}
{"type":"ai-title","aiTitle":"Login retry work"}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"I will look at the client."},{"type":"tool_use","name":"Read","input":{"file_path":"src/old.ts"}}]}}
{"type":"user","message":{"role":"user","content":[{"type":"tool_result","content":"IGNORE ME"}]}}
{"type":"user","isMeta":true,"message":{"role":"user","content":"meta caveat"}}
{"type":"user","message":{"role":"user","content":"<task-notification>done</task-notification>"}}
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"Also cover\tthe\nlogout path"}]}}
{"type":"assistant","isSidechain":true,"message":{"role":"assistant","content":[{"type":"text","text":"subagent text"}]}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Bash","input":{"command":"npm test","description":"Run the unit tests"}},{"type":"tool_use","name":"Edit","input":{"file_path":"src/logout.ts","old_string":"x"}}]}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Tests \u001b[31mfail\u001b[0m on logout."}]}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"te
EOF
"$summary_bin" --digest claude "$claude_transcript" >"$test_dir/digest.json"
jq -e '
  . == {
    title: "Login retry work",
    prompts: ["Add retry to the login client", "Also cover the logout path"],
    replies: ["I will look at the client.", "Tests fail on logout."],
    tools: ["Bash: Run the unit tests", "Edit: src/logout.ts"],
    key: "Alsocoverthelogoutpath"
  }
' "$test_dir/digest.json"

{
  printf '%s\n' '{"type":"title","v":1,"title":"OMP refactor","pad":"   "}'
  printf '%s\n' '{"type":"session","version":3,"cwd":"/repo"}'
  for i in $(seq 1 40); do
    printf '{"type":"message","message":{"role":"toolResult","content":[{"type":"text","text":"filler %s"}]}}\n' "$i"
  done
  printf '%s\n' '{"type":"message","message":{"role":"user","content":[{"type":"text","text":"Split the parser module"}]}}'
  printf '%s\n' '{"type":"message","message":{"role":"developer","content":[{"type":"text","text":"Continue."}]}}'
  printf '%s\n' '{"type":"message","message":{"role":"assistant","content":[{"type":"thinking"},{"type":"toolCall","name":"bash","arguments":{"i":"Running the parser tests","command":"cargo test"}},{"type":"toolCall","name":"read","arguments":{"path":"src/parser.rs"}}]}}'
  printf '%s\n' '{"type":"message","message":{"role":"toolResult","content":[{"type":"text","text":"ok"}]}}'
  printf '%s\n' '{"type":"message","message":{"role":"assistant","content":[{"type":"text","text":"Parser split into lexer and grammar."}]}}'
} >"$omp_transcript"
# Past the window, Claude's repeated last-prompt prefix stands in for the request.
{
  printf '%s\n' '{"type":"user","message":{"role":"user","content":"Port the CLI to Rust"}}'
  for i in $(seq 1 30); do
    printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Edit","input":{"file_path":"src/%s.rs"}}]}}\n' "$i"
  done
  printf '%s\n' '{"type":"last-prompt","lastPrompt":"Port the CLI to Rust","sessionId":"s"}'
} >"$test_dir/long.jsonl"
HERDR_AGENT_SUMMARY_TAIL_BYTES=1500 "$summary_bin" --digest claude "$test_dir/long.jsonl" >"$test_dir/digest.json"
jq -e '.prompts == ["Port the CLI to Rust"] and .key == "PorttheCLItoRust" and (.tools | length) == 8' \
  "$test_dir/digest.json"

# A small window starts mid-line and still finds the title on the first line.
HERDR_AGENT_SUMMARY_TAIL_BYTES=700 "$summary_bin" --digest omp "$omp_transcript" >"$test_dir/digest.json"
jq -e '
  . == {
    title: "OMP refactor",
    prompts: ["Split the parser module"],
    replies: ["Parser split into lexer and grammar."],
    tools: ["bash: Running the parser tests", "read: src/parser.rs"],
    key: "Splittheparsermodule"
  }
' "$test_dir/digest.json"

# --- Eligibility --------------------------------------------------------------

echo 'Fixing the login test' >"$CLAUDE_MODE"
agent worker claude worker-impl idle "$claude_session" '{"agent_summary":"old"}'
agent codex codex lead-codex idle '{"agent":"codex","kind":"id","value":"abc"}'
agent outside omp lead-outside idle '{"agent":"omp","kind":"path","value":"'"$test_dir"'/elsewhere/x.jsonl"}'
printf '{}\n' >"$test_dir/elsewhere/x.jsonl"
agent control claude lead-control idle '{"agent":"claude","kind":"id","value":"c0ffee-1\nworker-x"}'
for pane in worker codex outside control; do
  HERDR_PLUGIN_EVENT_JSON="{\"event\":\"pane_agent_status_changed\",\"data\":{\"type\":\"pane_agent_status_changed\",\"pane_id\":\"$pane\",\"agent_status\":\"idle\"}}" \
    "$summary_bin" --event
done
sleep 1
[ "$(calls)" = 0 ]
reports | jq -e '
  length == 1 and .[0].pane == "worker" and .[0].source == "local.agent-summary"
  and .[0].tokens == {agent_summary: null, agent_summary_stale: null}
'
rm "$AGENTS_DIR"/*.json
: >"$REPORT_LOG"

# --- Turn-end summary, isolation and sanitising -------------------------------

agent lead claude "" idle "$claude_session"
"$summary_bin" --final lead
[ "$(calls)" = 1 ]
jq -se --arg cwd "$HERDR_PLUGIN_STATE_DIR/claude-cwd" --arg config "$test_dir/claude-config" '
  last as $call
  | ($call.args | index("-p")) != null
  and ($call.args | index("--safe-mode")) != null
  and ($call.args | index("--no-session-persistence")) != null
  and ($call.args | index("--disable-slash-commands")) != null
  and ($call.args | (index("--tools") as $i | .[$i + 1] == ""))
  and ($call.args | (index("--model") as $i | .[$i + 1] == "haiku"))
  and ($call.args | (index("--settings") as $i | .[$i + 1] | fromjson.disableAllHooks == true))
  and ($call.args | (index("--output-format") as $i | .[$i + 1] == "json"))
  and $call.cwd == $cwd and $call.config == $config and $call.inherited == ""
  and ($call.input | contains("Agent state: idle"))
  and ($call.input | contains("- Edit: src/logout.ts"))
' "$CLAUDE_LOG"
last_report | jq -e '
  .pane == "lead" and .agent == "claude"
  and .tokens == {agent_summary: "\u200b    Fixing the login test", agent_summary_stale: null}
'

# Unchanged transcript: no model call, the stored line is shown as fresh.
"$summary_bin" --final lead
[ "$(calls)" = 1 ]
last_report | jq -e '.tokens.agent_summary == "\u200b    Fixing the login test"'

# A turn-end job already queued for the pane makes another one exit at once.
printf '%s\n' '{"type":"user","message":{"role":"user","content":"queued"}}' >>"$claude_transcript"
flock "$ns_dir/locks/lead.final" "$summary_bin" --final lead
[ "$(calls)" = 1 ]

check_reply() {
  printf '%s\n' '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"more"}]}}' \
    >>"$claude_transcript"
  printf '%s' "$1" >"$CLAUDE_MODE"
  "$summary_bin" --final lead
  last_report | jq -e --arg expected "$2" '.tokens.agent_summary == "\u200b    " + $expected'
}
check_reply $'\n  **Summary:** "Reviewing `auth` module."\nSecond line' 'Reviewing auth module'
# Octal UTF-8 bytes: \u escapes depend on the locale, which the build sandbox lacks.
check_reply $'\e[1mRunning\e[0m\ttests\342\200\213 now' 'Running tests now'
check_reply "$(printf 'x%.0s' $(seq 1 100))" "$(printf 'x%.0s' $(seq 1 59))…"
check_reply $'\342\200\234Drafting release notes\342\200\235' 'Drafting release notes'
check_reply 'Fixing agent_summary tokens' 'Fixing agent_summary tokens'

# Failures keep the previous line and mark it stale.
for mode in fail error; do
  printf '%s\n' '{"type":"user","message":{"role":"user","content":"next"}}' >>"$claude_transcript"
  echo "$mode" >"$CLAUDE_MODE"
  "$summary_bin" --final lead
  last_report | jq -e '
    .tokens == {agent_summary: null, agent_summary_stale: "\u200b    ◌ Fixing agent_summary tokens"}
  '
done
grep -q 'summary failed for lead' "$HERDR_PLUGIN_STATE_DIR/agent-summary.log"

# A hung model call is abandoned within the timeout.
# The fake model sleeps for 300 s; the outer timeout only guards the test.
echo slow >"$CLAUDE_MODE"
HERDR_AGENT_SUMMARY_TIMEOUT=1 timeout 60 "$summary_bin" --final lead
last_report | jq -e '.tokens.agent_summary_stale == "\u200b    ◌ Fixing agent_summary tokens"'

# --- Event hook and refresh loop ----------------------------------------------

echo 'Working on logout' >"$CLAUDE_MODE"
: >"$CLAUDE_LOG"
: >"$REPORT_LOG"
agent lead claude "" working "$claude_session"
# The hook returns promptly with its output pipe closed by the detached loop.
event='{"event":"pane_agent_status_changed","data":{"type":"pane_agent_status_changed","pane_id":"lead","agent_status":"working"}}'
HERDR_PLUGIN_EVENT_JSON="$event" timeout 60 "$bash_bin" -c '"$0" --event | cat' "$summary_bin"
# The grown transcript is marked stale until the loop replaces it.
reports | jq -e '.[0].tokens.agent_summary_stale == "\u200b    ◌ Fixing agent_summary tokens"'
# The loop's first pass summarises the new request.
wait_for '[ "$(calls)" -ge 1 ]'
wait_for 'last_report | jq -e ".tokens.agent_summary == \"\\u200b    Working on logout\"" >/dev/null'
# A second loop for the same pane exits while the first keeps its lock.
timeout 60 "$summary_bin" --loop lead
loop_lock="$ns_dir/locks/lead.loop"
fails() { if "$@"; then
  echo "unexpectedly succeeded: $*" >&2
  exit 1
fi; }
fails flock -n "$loop_lock" true
# Without transcript growth further loop passes only restore the line.
passes=$(($(wc -l <"$REPORT_LOG") + 2))
wait_for '[ "$(wc -l <"$REPORT_LOG")" -ge '"$passes"' ]'
[ "$(calls)" = 1 ]
printf '%s\n' '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Bash","input":{"command":"make"}}]}}' \
  >>"$claude_transcript"
wait_for '[ "$(calls)" = 2 ]'
jq -se 'last.input | contains("Agent state: working") and contains("- Bash: make")' "$CLAUDE_LOG"
# Leaving working stops the loop; the turn-end hook makes the final summary.
agent lead claude "" "done" "$claude_session"
wait_for 'flock -n "$loop_lock" true'
printf '%s\n' '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Finished."}]}}' \
  >>"$claude_transcript"
echo 'Finished logout retry' >"$CLAUDE_MODE"
HERDR_PLUGIN_EVENT_JSON="${event/working/done}" "$summary_bin" --event
wait_for '[ "$(calls)" = 3 ]'
wait_for 'last_report | jq -e ".tokens.agent_summary == \"\\u200b    Finished logout retry\"" >/dev/null'
jq -se 'last.input | contains("Agent state: done")' "$CLAUDE_LOG"

# A sleeping loop is woken by the next working event and picks up a new request.
agent lead claude "" working "$claude_session"
HERDR_AGENT_SUMMARY_INTERVAL=3600 "$summary_bin" --loop lead &
loop_pid=$!
wait_for '[ "$(calls)" = 4 ]'
printf '%s\n' '{"type":"user","message":{"role":"user","content":"Now add metrics"}}' >>"$claude_transcript"
echo 'Adding metrics' >"$CLAUDE_MODE"
HERDR_PLUGIN_EVENT_JSON="$event" "$summary_bin" --event
# Well inside the hour-long interval.
wait_for '[ "$(calls)" = 5 ]'
jq -se 'last.input | contains("- Now add metrics")' "$CLAUDE_LOG"
agent lead claude "" idle "$claude_session"
: >"$ns_dir/locks/lead.kick"
wait_for "! kill -0 $loop_pid 2>/dev/null"
"$summary_bin" --final lead
[ "$(calls)" = 6 ]

# A loop outlives a transcript that does not exist yet and exits when its pane closes.
fresh_session='{"agent":"claude","kind":"id","value":"fresh-2"}'
agent fresh claude "" working "$fresh_session"
"$summary_bin" --loop fresh &
loop_pid=$!
sleep 2
kill -0 "$loop_pid"
[ "$(calls)" = 6 ]
printf '%s\n' '{"type":"user","message":{"role":"user","content":"Start fresh"}}' \
  >"$test_dir/claude-config/projects/-repo/fresh-2.jsonl"
wait_for '[ "$(calls)" = 7 ]'
rm "$AGENTS_DIR/fresh.json"
wait_for "! kill -0 $loop_pid 2>/dev/null"

# --- Unresponsive Herdr and bounded locks ------------------------------------

export HERDR_AGENT_SUMMARY_RPC_TIMEOUT=1
agent lead claude "" working "$claude_session"
: >"$HANG_FILE"
# The outer timeouts only guard the test; each command must finish by itself.
HERDR_PLUGIN_EVENT_JSON="$event" timeout 60 "$summary_bin" --event
timeout 60 "$summary_bin" --loop lead
flock -n "$loop_lock" true
timeout 60 "$summary_bin" --startup
rm "$HANG_FILE"
# A model lock held past the wait makes the job give up instead of queueing forever.
exec 9>"$model_lock"
flock 9
HERDR_AGENT_SUMMARY_LOCK_WAIT=1 timeout 60 "$summary_bin" --final lead 9>&-
exec 9>&-
grep -q 'model lock wait timed out for lead' "$HERDR_PLUGIN_STATE_DIR/agent-summary.log"
unset HERDR_AGENT_SUMMARY_RPC_TIMEOUT

# --- A pane that changes while its summary is running -------------------------

mkdir -p "$BARRIER_DIR"
idle_event="${event/working/idle}"
old_line='"\u200b    Old lead task"'
# Starts a turn-end summary that blocks inside the model until released.
start_held_summary() {
  rm -f "$BARRIER_DIR/called" "$BARRIER_DIR/release"
  echo barrier >"$CLAUDE_MODE"
  "$summary_bin" --final lead &
  final_pid=$!
  wait_for '[ -e "$BARRIER_DIR/called" ]'
}
release_held_summary() {
  : >"$BARRIER_DIR/release"
  wait "$final_pid"
  wait_for 'flock -n "$ns_dir/locks/lead.final" true && flock -n "$model_lock" true'
}
no_old_line() {
  reports | jq -e --argjson old "$old_line" 'all(.[]; .tokens.agent_summary != $old)'
}

# The request changes: the old result is dropped, not stored under the new request.
agent lead claude "" idle "$claude_session"
printf '%s\n' '{"type":"user","message":{"role":"user","content":"Review old lead task"}}' >>"$claude_transcript"
start_held_summary
printf '%s\n' '{"type":"user","message":{"role":"user","content":"Review the new task"}}' >>"$claude_transcript"
: >"$REPORT_LOG"
release_held_summary
no_old_line
grep -c 'discarded an obsolete summary for lead' "$HERDR_PLUGIN_STATE_DIR/agent-summary.log"
jq -e '.summary != "Old lead task"' "$ns_dir/panes/lead.json"

# Another eligible session takes the pane: its stale line is cleared and the old
# session's result is not shown as the new session's.
printf '%s\n' '{"type":"user","message":{"role":"user","content":"Other session work"}}' \
  >"$test_dir/claude-config/projects/-repo/other-9.jsonl"
start_held_summary
agent lead claude "" idle '{"agent":"claude","kind":"id","value":"other-9"}' '{"agent_summary":"previous"}'
: >"$REPORT_LOG"
HERDR_PLUGIN_EVENT_JSON="$idle_event" "$summary_bin" --event
reports | jq -e '.[0].tokens == {agent_summary: null, agent_summary_stale: null}'
echo 'New session work' >"$CLAUDE_MODE"
release_held_summary
no_old_line
last_report | jq -e '.tokens.agent_summary == "\u200b    New session work"'
jq -e '.identity == "claude:id:other-9"' "$ns_dir/panes/lead.json"

# A worker takes the pane: every later report clears and the old result is dropped.
agent lead claude "" idle "$claude_session"
printf '%s\n' '{"type":"user","message":{"role":"user","content":"Review old lead task"}}' >>"$claude_transcript"
start_held_summary
agent lead claude worker-replacement idle '{"agent":"claude","kind":"id","value":"other-9"}' \
  '{"agent_summary":"previous"}'
: >"$REPORT_LOG"
HERDR_PLUGIN_EVENT_JSON="$idle_event" "$summary_bin" --event
release_held_summary
reports | jq -e '
  length >= 1 and all(.[]; .pane == "lead"
    and .tokens == {agent_summary: null, agent_summary_stale: null})
'
[ ! -e "$ns_dir/panes/lead.json" ]

# The hook clears an ineligible pane at once and again after a busy model lock.
: >"$REPORT_LOG"
exec 9>"$model_lock"
flock 9
HERDR_PLUGIN_EVENT_JSON="$idle_event" "$summary_bin" --event 9>&-
[ "$(wc -l <"$REPORT_LOG")" = 1 ]
exec 9>&-
wait_for '[ "$(wc -l <"$REPORT_LOG")" = 2 ]'
reports | jq -e 'all(.[]; .tokens == {agent_summary: null, agent_summary_stale: null})'

# --- A failed refresh stays stale through events and startup -------------------

echo 'Old lead task' >"$CLAUDE_MODE"
agent lead claude "" idle "$claude_session"
"$summary_bin" --final lead
last_report | jq -e '.tokens.agent_summary == "\u200b    Old lead task"'
printf '%s\n' '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"More work"}]}}' \
  >>"$claude_transcript"
echo fail >"$CLAUDE_MODE"
"$summary_bin" --final lead
jq -e '.failed == true' "$ns_dir/panes/lead.json"
# Hold every model slot so no retry can land between the restores below.
exec 3>"$HERDR_PLUGIN_STATE_DIR/slots/slot.0" 4>"$HERDR_PLUGIN_STATE_DIR/slots/slot.1"
flock 3
flock 4
failures=$(grep -c 'summary failed for lead' "$HERDR_PLUGIN_STATE_DIR/agent-summary.log")
: >"$REPORT_LOG"
# The test's lock descriptors stay out of the plugin's processes.
HERDR_AGENT_SUMMARY_TIMEOUT=1 HERDR_PLUGIN_EVENT_JSON="${event/working/idle}" "$summary_bin" --event 3>&- 4>&-
HERDR_AGENT_SUMMARY_TIMEOUT=1 "$summary_bin" --startup 3>&- 4>&-
# The retry spawned by those restores finds no free slot and fails too.
wait_for '[ "$(grep -c "summary failed for lead" "$HERDR_PLUGIN_STATE_DIR/agent-summary.log")" -gt '"$failures"' ]'
exec 3>&- 4>&-
# A queued retry holds the turn-end or model lock until it ends.
wait_for 'flock -n "$ns_dir/locks/lead.final" true && flock -n "$model_lock" true'
reports | jq -e '
  [.[] | select(.pane == "lead")] | length >= 2
  and all(.[]; .tokens == {agent_summary: null, agent_summary_stale: "\u200b    ◌ Old lead task"})
'

# --- Startup, restore and cleanup ---------------------------------------------

echo 'Adding metrics' >"$CLAUDE_MODE"
printf '%s\n' '{"type":"user","message":{"role":"user","content":"Now add metrics"}}' >>"$claude_transcript"
"$summary_bin" --final lead
last_report | jq -e '.tokens.agent_summary == "\u200b    Adding metrics"'
jq -e '.failed == false' "$ns_dir/panes/lead.json"

# Files left by an older layout or a permissive umask are tightened.
chmod 755 "$HERDR_PLUGIN_STATE_DIR" "$ns_dir/locks"
printf '{}\n' >"$ns_dir/panes/gone.json"
chmod 644 "$ns_dir/panes/gone.json" "$ns_dir/panes/lead.json" "$HERDR_PLUGIN_STATE_DIR/agent-summary.log"

: >"$CLAUDE_LOG"
: >"$REPORT_LOG"
agent lead claude "" idle "$claude_session"
agent omp omp "" idle "$omp_session"
echo 'Splitting the parser' >"$CLAUDE_MODE"
"$summary_bin" --startup
[ ! -e "$ns_dir/panes/gone.json" ]
[ ! -e "$ns_dir/panes/fresh.json" ]
# The stored summary is restored without a model call; OMP gets its first one.
wait_for '[ "$(calls)" = 1 ]'
wait_for 'reports | jq -e "any(.[]; .pane == \"omp\" and .tokens.agent_summary == \"\\u200b    Splitting the parser\")" >/dev/null'
reports | jq -e 'any(.[]; .pane == "lead" and .tokens.agent_summary == "\u200b    Adding metrics")'
jq -se 'last.input | contains("Session title: OMP refactor")' "$CLAUDE_LOG"
wait_for '[ -e "$ns_dir/panes/omp.json" ]'
[ -z "$(find "$HERDR_PLUGIN_STATE_DIR" \( -type d ! -perm 700 \) -o \( -type f ! -perm 600 \))" ]

# --- Startup cleanup racing a new pane ----------------------------------------

# A pane created after startup's snapshot keeps its lock file and its one loop.
printf '{}\n' >"$ns_dir/panes/late.json"
: >"$SNAPSHOT_BARRIER"
"$summary_bin" --startup &
startup_pid=$!
wait_for '[ -e "$SNAPSHOT_BARRIER.ready" ]'
agent brandnew claude "" working '{"agent":"claude","kind":"id","value":"brand-new-1"}'
# A cached pane that the held snapshot missed but that exists by pruning time.
agent late codex "" idle '{"agent":"codex","kind":"id","value":"late"}'
HERDR_AGENT_SUMMARY_INTERVAL=3600 "$summary_bin" --loop brandnew &
first_loop=$!
new_lock="$ns_dir/locks/brandnew.loop"
wait_for '[ -e "$new_lock" ] && ! flock -n "$new_lock" true'
inode="$(stat -c %i "$new_lock")"
# A gone pane's cache is pruned; one whose writer holds its model lock is kept.
for key in gone busy; do
  printf '{}\n' >"$ns_dir/panes/$key.json"
  printf '{}\n' >"$ns_dir/panes/$key.json.12345"
done
exec 9>"$ns_dir/locks/busy.model"
flock 9
: >"$SNAPSHOT_BARRIER.release"
wait "$startup_pid"
exec 9>&-
[ "$(stat -c %i "$new_lock")" = "$inode" ]
timeout 60 "$summary_bin" --loop brandnew
kill -0 "$first_loop"
fails flock -n "$new_lock" true
[ ! -e "$ns_dir/panes/gone.json" ]
[ ! -e "$ns_dir/panes/gone.json.12345" ]
[ -e "$ns_dir/panes/busy.json" ]
[ -e "$ns_dir/panes/busy.json.12345" ]
[ -e "$ns_dir/panes/late.json" ]
rm "$AGENTS_DIR/late.json"
rm "$AGENTS_DIR/brandnew.json"
: >"$ns_dir/locks/brandnew.kick"
wait "$first_loop"

# More stale caches than the startup process has descriptors: pruning works in
# lock batches, and current panes are still reconciled.
for i in $(seq 1 300); do
  printf '{}\n' >"$ns_dir/panes/closed-$i.json"
done
printf '{}\n' >"$ns_dir/panes/closed-7.json.999"
printf '{}\n' >"$ns_dir/panes/late.json"
exec 9>"$ns_dir/locks/busy.model"
flock 9
: >"$REPORT_LOG"
rm -f "$SNAPSHOT_BARRIER.ready" "$SNAPSHOT_BARRIER.release"
: >"$SNAPSHOT_BARRIER"
"$bash_bin" -c 'ulimit -n 64 && exec "$0" --startup' "$summary_bin" 9>&- &
startup_pid=$!
wait_for '[ -e "$SNAPSHOT_BARRIER.ready" ]'
agent late codex "" idle '{"agent":"codex","kind":"id","value":"late"}'
: >"$SNAPSHOT_BARRIER.release"
wait "$startup_pid"
exec 9>&-
[ -z "$(find "$ns_dir/panes" -name 'closed-*')" ]
[ -e "$ns_dir/panes/busy.json" ]
[ -e "$ns_dir/panes/late.json" ]
reports | jq -e 'any(.[]; .pane == "lead") and any(.[]; .pane == "omp")'
rm "$AGENTS_DIR/late.json" "$ns_dir/panes/late.json"
# Let the turn-end jobs that startup spawned finish before the next check.
for key in lead omp; do
  wait_for 'flock -n "$ns_dir/locks/'"$key"'.final" true && flock -n "$ns_dir/locks/'"$key"'.model" true'
done

# A second server sharing the plugin state keeps its own panes, locks and cache.
AGENTS_DIR="$test_dir/agents-b" HERDR_SOCKET_PATH="$test_dir/sock-b" \
  "$bash_bin" -c 'mkdir -p "$AGENTS_DIR" && printf "%s\n" "{\"pane_id\":\"other\",\"agent\":\"codex\"}" >"$AGENTS_DIR/other.json" && "$0" --startup' \
  "$summary_bin"
[ -e "$ns_dir/panes/lead.json" ]
[ -e "$ns_dir/panes/omp.json" ]
[ "$(find "$HERDR_PLUGIN_STATE_DIR/servers" -mindepth 1 -maxdepth 1 -type d | wc -l)" = 2 ]

: >"$REPORT_LOG"
agent lead claude "" idle "$claude_session" '{"agent_summary":"x"}'
"$summary_bin" --clear
reports | jq -e '
  [.[] | select(.tokens == {agent_summary: null, agent_summary_stale: null})]
  | length == 1 and .[0].pane == "lead"
'
[ -z "$(find "$ns_dir/panes" -name '*.json')" ]

printf 'Agent summary fixtures passed.\n'
