#!/usr/bin/env bash

set -euo pipefail

display_bin="$1"
bash_bin="$2"
rows_file="$3"
palette_file="$4"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

export REPORT_LOG="$test_dir/reports"
export SNAPSHOT_FILE="$test_dir/snapshot.json"
export HERDR_BIN_PATH="$test_dir/herdr"
: >"$REPORT_LOG"
export HERDR_AGENT_DISPLAY_LEAD_PREFIXES='["lead-"]'
export HERDR_AGENT_DISPLAY_WORKER_PREFIXES='["worker-"]'
export HERDR_AGENT_DISPLAY_PLAIN_LEADS='["lead-plain"]'
export HERDR_AGENT_DISPLAY_TITLE_ROWS=none

cat >"$SNAPSHOT_FILE" <<'EOF'
{"result":{"snapshot":{
"agents": [
  {"workspace_id":"w1","tab_id":"t1","pane_id":"lead","agent":"codex","name":"lead-alpha","terminal_title":"✳ Review changes","terminal_title_stripped":"Review changes","title":"lead-task","tokens":{"title":"feature-a"},"agent_status":"idle"},
  {"workspace_id":"w1","tab_id":"t2","pane_id":"impl","agent":"claude","name":"worker-implementation","terminal_title":"◐ Inspect result","terminal_title_stripped":"Inspect result","title":"feature-a","tokens":{"title":"implementation","agent_repository_header":"stale-repo","agent_workspace_header":"stale-worktree","agent_primary":"stale-name","agent_secondary":"stale-context"},"agent_status":"blocked"},
  {"workspace_id":"w1","tab_id":"t3","pane_id":"worker","agent":"claude","name":"worker-helper","terminal_title":"π ⠹ Apply changes","terminal_title_stripped":"π ⠹ Apply changes","title":"claude","tokens":{},"agent_status":"done"},
  {"workspace_id":"wx","tab_id":"tx","pane_id":"notes","agent":"claude","name":"lead-plain","terminal_title":"π > Publish results","terminal_title_stripped":"π > Publish results","title":"notes","tokens":{"agent_lead_quiet":"stale-lead"},"agent_status":"idle"},
  {"workspace_id":"w2","tab_id":"t4","pane_id":"review","agent":"codex","name":"lead-reviewer","terminal_title":"◉ > Write draft","title":"feature-b","tokens":{"title":"project"},"agent_status":"idle"},
  {"workspace_id":"w2","tab_id":"t5","pane_id":"writer","agent":"claude","name":"worker-writer","terminal_title":"修正 作業","title":"project","tokens":{},"agent_status":"idle"},
  {"workspace_id":"w0","tab_id":"t6","pane_id":"root","agent":"codex","name":"lead-root","terminal_title":"⠹ 修正 作業","title":"project","tokens":{},"agent_status":"working"},
  {"workspace_id":"w0","tab_id":"t7","pane_id":"child","agent":"claude","name":"worker-child","terminal_title":"π + 1","title":"child","tokens":{"agent_display":"old-child","agent_primary":"└─ claude"},"agent_status":"done"},
  {"workspace_id":"w3","tab_id":"t8","pane_id":"solo","agent":"codex","name":"lead-solo","terminal_title":"Build > Test pipeline","title":"solo","tokens":{},"agent_status":"idle"},
  {"workspace_id":"w3","tab_id":"t9","pane_id":"cleanup","agent":"claude","name":"worker-cleanup","terminal_title":"x->y rename","title":"solo","tokens":{"agent_repository_header":"stale","agent_secondary":"stale"},"agent_status":"blocked"},
  {"workspace_id":"missing","tab_id":"missing-tab","pane_id":"orphan","agent":"codex","name":"orphan","terminal_title":"A > B","title":"orphan","tokens":{}},
  {"workspace_id":"w4","tab_id":"t10","pane_id":"alone","agent":"codex","name":"lead-alone","terminal_title":"A + B","title":"alone","tokens":{},"agent_status":"idle"},
  {"workspace_id":"w5","tab_id":"t11","pane_id":"first","agent":"claude","name":"worker-first","terminal_title":"修 > 作業","title":"fresh","tokens":{},"agent_status":"idle"},
  {"workspace_id":"w3","tab_id":"t8","pane_id":"ignored","agent":"","name":"ignored","tokens":{"agent_primary":"stale"}}
],
"workspaces": [
  {"workspace_id":"w0","label":"project","worktree":{"repo_key":"repo","repo_name":"project","repo_root":"/repo","checkout_path":"/repo","is_linked_worktree":false}},
  {"workspace_id":"w1","label":"feature-a","worktree":{"repo_key":"repo","repo_name":"project","repo_root":"/repo","checkout_path":"/worktrees/a","is_linked_worktree":true}},
  {"workspace_id":"wx","label":"notes"},
  {"workspace_id":"w2","label":"feature-b","worktree":{"repo_key":"repo","repo_name":"project","repo_root":"/repo","checkout_path":"/worktrees/b","is_linked_worktree":true}},
  {"workspace_id":"w3","label":"solo"},
  {"workspace_id":"w4","label":"alone"},
  {"workspace_id":"w5","label":"fresh"}
],
"tabs": [
  {"tab_id":"t1","workspace_id":"w1","label":"1"},
  {"tab_id":"t2","workspace_id":"w1","label":"impl-task"},
  {"tab_id":"t3","workspace_id":"w1","label":"unique-task"},
  {"tab_id":"tx","workspace_id":"wx","label":"notes-task"},
  {"tab_id":"t4","workspace_id":"w2","label":"review-task"},
  {"tab_id":"t5","workspace_id":"w2","label":"5"},
  {"tab_id":"t6","workspace_id":"w0","label":"root-task"},
  {"tab_id":"t7","workspace_id":"w0","label":"7"},
  {"tab_id":"t8","workspace_id":"w3","label":"8"},
  {"tab_id":"t9","workspace_id":"w3","label":"cleanup-task"},
  {"tab_id":"t10","workspace_id":"w4","label":"alone-task"},
  {"tab_id":"t11","workspace_id":"w5","label":"first-task"}
]
}}}
EOF

printf '#!%s\n' "$bash_bin" >"$HERDR_BIN_PATH"
cat >>"$HERDR_BIN_PATH" <<'EOF'
set -euo pipefail

case "$1:$2" in
  api:snapshot)
    [ "${FAIL_SNAPSHOT:-0}" = 0 ] || exit 1
    cat "$SNAPSHOT_FILE"
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

"$display_bin" --all

reports="$test_dir/parsed-reports.json"
parse_reports() {
  jq -s '
    map(. as $args | {
      pane: .[2], source: .[4], agent: .[6], seq: .[8],
      tokens: (reduce range(9; length; 2) as $i ({};
        if $args[$i] == "--token"
        then ($args[$i + 1] | index("=")) as $eq
          | . + {($args[$i + 1][0:$eq]): $args[$i + 1][$eq + 1:]}
        else . + {($args[$i + 1]): null}
        end))
    })
  ' "$REPORT_LOG" >"$reports"
  jq -e '
    all(.[];
      if .tokens.agent_lead != null
      then (.tokens.agent_lead | test("^\u200b(?: {2})?[^ ]"))
      elif (.tokens.agent_worker // .tokens.agent_worker_quiet) != null
      then (.tokens.agent_worker // .tokens.agent_worker_quiet | test("^\u200b(?: {2}| {4})[^ ]"))
      else true end)
  ' "$reports" >/dev/null
}
parse_reports

jq -e '
  map(.pane) == ["lead", "impl", "worker", "notes", "review", "writer", "root", "child", "solo", "cleanup", "orphan", "alone", "first"]
  and all(.[];
    .source == "local.agent-display"
    and (.agent == "codex" or .agent == "claude")
    and (.seq | test("^[0-9]+$"))
    and ([.tokens.agent_lead,
          .tokens.agent_worker, .tokens.agent_worker_quiet]
         | map(select(. != null)) | length) == 1
    and all(.tokens[]; . == null or length <= 80))
  and all(.[]; .tokens.agent_lead_quiet == null)
' "$reports"

jq -e '
  map([.pane, .tokens.agent_repository_header, .tokens.agent_workspace_header,
       (.tokens.agent_lead // .tokens.agent_worker)]) == [
    ["lead", "project", null, "\u200b⋯ feature-a"],
    ["impl", null, null, "\u200b    ! implementation"],
    ["worker", null, null, "\u200b    ✓ helper"],
    ["notes", null, "\u200b  notes", "\u200b– plain"],
    ["review", "project", null, "\u200b◇ feature-b"],
    ["writer", null, null, "\u200b    – writer"],
    ["root", null, null, "\u200b  ▶ root"],
    ["child", null, null, "\u200b    ✓ child"],
    ["solo", null, null, "\u200b  ⋯ solo"],
    ["cleanup", null, null, "\u200b    ! cleanup"],
    ["orphan", null, "\u200b  missing", "\u200b? orphan"],
    ["alone", null, null, "\u200b  ◇ alone"],
    ["first", null, "\u200b  fresh", "\u200b  – first"]
  ]
  and all(.[];
    .tokens.agent_title == null and .tokens.agent_group_gap == null
    and .tokens.agent_primary == null
    and .tokens.agent_primary_old == null
    and .tokens.agent_primary_stale == null
    and .tokens.agent_secondary == null)
' "$reports"

# Continuation rows gain two cells; every row type keeps one absolute column.
jq -e '
  def padding: sub("^\u200b"; "") | capture("^(?<spaces> *)").spaces | length;
  all(.[];
    . as $report
    | [[["agent_repository_header", 1], ["agent_workspace_header", 3],
        ["agent_lead", 3], ["agent_worker", 5], ["agent_worker_quiet", 5]][] as [$token, $column]
      | $report.tokens[$token] | select(. != null) | {text: ., column: $column}]
    | to_entries | all(.[];
        (.value.text | padding) + (if .key == 0 then 1 else 3 end) == .value.column))
  and all(.[].tokens[]; . == null or (test("[└├│─]") | not))
' "$reports"

jq '.result.snapshot.agents[10].agent_status = "idle"' \
  "$SNAPSHOT_FILE" >"$test_dir/unclassified.json"
: >"$REPORT_LOG"
SNAPSHOT_FILE="$test_dir/unclassified.json" "$display_bin" --all
parse_reports
jq -e '.[10].tokens.agent_lead == "\u200b– orphan"' "$reports"

# An unnamed worker uses its agent label in both its row and the wait scan.
jq '.result.snapshot.agents |= .[:2]
  | .result.snapshot.agents[1].name = ""' "$SNAPSHOT_FILE" >"$test_dir/unnamed-worker.json"
: >"$REPORT_LOG"
HERDR_AGENT_DISPLAY_WORKER_PREFIXES='["claude"]' \
  SNAPSHOT_FILE="$test_dir/unnamed-worker.json" "$display_bin" --all
parse_reports
jq -e '.[0].tokens.agent_lead == "\u200b⋯ feature-a"
  and .[1].tokens.agent_worker == "\u200b    ! claude"' "$reports"

jq '
  .result.snapshot.agents[0].agent_status = "done"
  | .result.snapshot.agents[1].agent_status = "working"
' "$SNAPSHOT_FILE" >"$test_dir/working-worker.json"
: >"$REPORT_LOG"
SNAPSHOT_FILE="$test_dir/working-worker.json" "$display_bin" --all
parse_reports
jq -e '.[0].tokens.agent_lead == "\u200b⋯ feature-a"
  and .[1].tokens.agent_worker == "\u200b    ▶ implementation"' "$reports"

jq '
  .result.snapshot.workspaces[] |=
    (if .workspace_id == "w2" then .worktree.repo_key = "other" | .worktree.repo_name = "other"
     else . end)
' "$SNAPSHOT_FILE" >"$test_dir/options.json"
: >"$REPORT_LOG"
HERDR_AGENT_DISPLAY_TITLE_ROWS=all HERDR_AGENT_DISPLAY_GROUP_GAP=repositories \
  SNAPSHOT_FILE="$test_dir/options.json" "$display_bin" --all
parse_reports
jq -e '
  .[0].tokens.agent_title == "\u200b  Review changes"
  and .[1].tokens.agent_title == "\u200b    Inspect result"
  and .[2].tokens.agent_title == "\u200b    Apply changes"
  and .[3].tokens.agent_title == "\u200b  Publish results"
  and .[4].tokens.agent_title == "\u200b  Write draft"
  and .[5].tokens.agent_title == "\u200b    修正 作業"
  and .[6].tokens.agent_title == "\u200b  修正 作業"
  and .[7].tokens.agent_title == "\u200b    π + 1"
  and .[8].tokens.agent_title == "\u200b  Build > Test pipeline"
  and .[9].tokens.agent_title == "\u200b    x->y rename"
  and .[10].tokens.agent_title == "\u200b  A > B"
  and .[11].tokens.agent_title == "\u200b  A + B"
  and .[12].tokens.agent_title == "\u200b    修 > 作業"
  and all(.[];
    (.tokens.agent_title | startswith("\u200b"))
    and (.tokens.agent_lead // .tokens.agent_worker) != null)
  and ([.[] | select(.tokens.agent_group_gap != null) | .pane] == ["notes", "writer"])
  and .[4].tokens.agent_repository_header == "other"
  and .[6].tokens.agent_repository_header == "project"
' "$reports"

jq '
  .result.snapshot.agents[1] += {agent_status: "idle", terminal_id: "term-impl", state_change_seq: 2}
  | .result.snapshot.agents[1].tokens.agent_activity = "term-impl|2|idle|1000"
' "$SNAPSHOT_FILE" >"$test_dir/worker-age.json"
: >"$REPORT_LOG"
HERDR_AGENT_DISPLAY_NOW=10000 SNAPSHOT_FILE="$test_dir/worker-age.json" "$display_bin" --all
parse_reports
jq -e '
  .[0].tokens.agent_lead == "\u200b◇ feature-a"
  and .[1].tokens.agent_worker_quiet == "\u200b    – implementation"
  and .[1].tokens.agent_worker == null
' "$reports"

FAIL_SNAPSHOT=1 "$display_bin" --all
[ "$(wc -l <"$REPORT_LOG")" -eq 13 ]

for status in working blocked 'done' idle unknown; do
  jq --arg status "$status" '.result.snapshot.agents[0].agent_status = $status' \
    "$SNAPSHOT_FILE" >"$test_dir/next.json"
  mv "$test_dir/next.json" "$SNAPSHOT_FILE"
  : >"$REPORT_LOG"
  "$display_bin" --all
  parse_reports
  case "$status" in
  working) mark=▶ ;;
  blocked) mark='!' ;;
  done | idle) mark=⋯ ;;
  unknown) mark='?' ;;
  esac
  jq -e --arg mark "$mark" '.[0].tokens.agent_lead == "\u200b" + $mark + " feature-a"' "$reports"
done

# Rows must match a configured rule; Herdr reports done until a completion is seen.
check_style() {
  local pane="$1" status="$2" token="$3" expected="$4" slot="$5" bold="$6" dim="$7"
  jq --arg pane "$pane" --arg status "$status" '
    .result.snapshot.agents |= map(if .pane_id == $pane then .agent_status = $status else . end)
  ' "$SNAPSHOT_FILE" >"$test_dir/style.json"
  : >"$REPORT_LOG"
  SNAPSHOT_FILE="$test_dir/style.json" "$display_bin" --all
  parse_reports
  jq -e --arg pane "$pane" --arg token "$token" --arg expected "$expected" --arg slot "$slot" \
    --argjson bold "$bold" --argjson dim "$dim" --slurpfile rows "$rows_file" \
    --slurpfile palette "$palette_file" '
    first(.[] | select(.pane == $pane)).tokens[$token] as $text
    | first($rows[0][][] | objects | select(.token == "$" + $token)).rules as $rules
    | first($rules[] | select(.contains as $mark | $text | contains($mark)))
    | $text == "\u200b" + $expected
      and .fg == $palette[0][$slot] and .bold == $bold and .dim == $dim
  ' "$reports" >/dev/null
}
check_style alone 'done' agent_lead '  ◆ alone' base0D true false
check_style alone idle agent_lead '  ◇ alone' base05 false false
check_style alone working agent_lead '  ▶ alone' base0E false false
check_style alone blocked agent_lead '  ! alone' base08 true false
check_style alone unknown agent_lead '  ? alone' base05 false false
check_style notes working agent_lead '▶ plain' base0E false false
check_style notes blocked agent_lead '! plain' base08 true false
check_style notes idle agent_lead '– plain' base05 false false
check_style notes 'done' agent_lead '✓ plain' base0B false false
check_style lead idle agent_lead '⋯ feature-a' base0E false true
check_style solo idle agent_lead '  ⋯ solo' base0E false true
check_style review 'done' agent_lead '◆ feature-b' base0D true false
check_style first working agent_worker '  ▶ first' base0E false false
check_style first blocked agent_worker '  ! first' base08 true false
check_style first idle agent_worker '  – first' base05 false true
check_style first 'done' agent_worker '  ✓ first' base0B false true
check_style first unknown agent_worker '  ? first' base05 false true
check_style impl working agent_worker '    ▶ implementation' base0E false false
check_style child 'done' agent_worker '    ✓ child' base0B false true

# Text uses only base05 and accent slots, never the base03/base04 surface greys.
jq -e --slurpfile palette "$palette_file" '
  [.. | objects | select(has("fg")) | .fg] | unique
  | all(.[]; . != $palette[0].base03 and . != $palette[0].base04)
' "$rows_file" >/dev/null

# Idle age is carried in owned metadata and advances only when a hook reruns this command.
check_age() {
  local activity="$1" expected_token="$2" session="${3:-null}" state_seq="${4:-2}"
  jq --arg activity "$activity" --argjson session "$session" --argjson state_seq "$state_seq" '
    .result.snapshot.agents[0] += {
      agent_status: "idle", terminal_id: "term-lead", state_change_seq: $state_seq,
      agent_session: $session
    }
    | .result.snapshot.agents[0].tokens.agent_activity = $activity
    | .result.snapshot.agents[1].agent_status = "done"
  ' "$SNAPSHOT_FILE" >"$test_dir/age.json"
  : >"$REPORT_LOG"
  HERDR_AGENT_DISPLAY_NOW=10000 SNAPSHOT_FILE="$test_dir/age.json" "$display_bin" --all
  parse_reports
  jq -e --arg token "$expected_token" '
    .[0].tokens[$token] == "\u200b◇ feature-a"
    and ([.[0].tokens.agent_lead,
          .[0].tokens.agent_worker, .[0].tokens.agent_worker_quiet]
         | map(select(. != null)) | length) == 1
  ' "$reports"
}
check_age 'term-lead|2|idle|9160' agent_lead
check_age 'term-lead|2|idle|9100' agent_lead
check_age 'term-lead|2|idle|9099' agent_lead
check_age 'term-lead|2|idle|2800' agent_lead

# Focus/manual refresh leaves an unchanged idle timestamp alone; a new terminal cannot inherit it.
jq -e '.[0].tokens.agent_activity == "term-lead|2|idle|2800"' "$reports"
check_age 'old-terminal|2|idle|2800' agent_lead
jq -e '.[0].tokens.agent_activity == "term-lead|2|idle|"' "$reports"
check_age 'term-lead|2|idle|' agent_lead
jq -e '.[0].tokens.agent_activity == "term-lead|2|idle|"' "$reports"

# The working-to-idle state event records its observation time, starting in the fresh tier.
check_age 'term-lead|1|working|1000' agent_lead
jq -e '.[0].tokens.agent_activity == "term-lead|2|idle|10000"' "$reports"

# Native sessions distinguish occupants and preserve known work across non-working states.
session='{"agent":"codex","kind":"id","value":"session-a"}'
check_age 'codex:id:session-old|2|idle|2800' agent_lead "$session"
jq -e '.[0].tokens.agent_activity == "codex:id:session-a|2|idle|"' "$reports"
check_age 'codex:id:session-a|2|done|2800' agent_lead "$session" 3
jq -e '.[0].tokens.agent_activity == "codex:id:session-a|3|idle|2800"' "$reports"

# Without a native session, an unobserved lifecycle change invalidates old age.
check_age 'term-lead|2|idle|2800' agent_lead null 3
jq -e '.[0].tokens.agent_activity == "term-lead|3|idle|"' "$reports"

# Unsafe or oversized native identities stay age-unknown and are not persisted.
session='{"agent":"codex","kind":"id","value":"bad|session"}'
check_age 'term-lead|2|idle|2800' agent_lead "$session"
jq -e '.[0].tokens.agent_activity == null' "$reports"
session='{"agent":"codex","kind":"id","value":"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}'
check_age 'term-lead|2|idle|2800' agent_lead "$session"
jq -e '.[0].tokens.agent_activity == null' "$reports"

# An initially idle agent has no invented history.
jq 'del(.result.snapshot.agents[0].tokens.agent_activity, .result.snapshot.agents[0].agent_session)' \
  "$test_dir/age.json" >"$test_dir/no-history.json"
: >"$REPORT_LOG"
HERDR_AGENT_DISPLAY_NOW=10000 SNAPSHOT_FILE="$test_dir/no-history.json" "$display_bin" --all
parse_reports
jq -e '
  .[0].tokens.agent_lead == "\u200b◇ feature-a"
  and .[0].tokens.agent_activity == "term-lead|2|idle|"
' "$reports"

# Clear new tokens and retired layouts, even for panes with only old metadata.
: >"$REPORT_LOG"
"$display_bin" --clear
parse_reports
jq -e '
  map(.pane) == ["impl", "notes", "child", "cleanup"]
  and all(.[];
    (.tokens | keys) == (["agent_activity", "agent_display", "agent_group_gap",
      "agent_lead", "agent_lead_quiet", "agent_primary", "agent_primary_old",
      "agent_primary_stale", "agent_repository_header", "agent_secondary",
      "agent_title", "agent_worker", "agent_worker_quiet", "agent_workspace_header"] | sort)
    and all(.tokens[]; . == null))
' "$reports"

# A lane lead falls back to its own name when Herdr chose the workspace label.
check_lane_label() {
  local label="$1" expected="$2"
  jq --arg label "$label" '
    .result.snapshot.agents[0].agent_status = "working"
    | .result.snapshot.workspaces |= map(if .workspace_id == "w1" then .label = $label else . end)
    | .result.snapshot.panes = [{pane_id: "lead", workspace_id: "w1", cwd: "/src/checkout"}]
  ' "$SNAPSHOT_FILE" >"$test_dir/lane.json"
  : >"$REPORT_LOG"
  SNAPSHOT_FILE="$test_dir/lane.json" "$display_bin" --all
  parse_reports
  jq -e --arg expected "$expected" '
    .[0].tokens.agent_lead == "\u200b▶ " + $expected
    and .[0].tokens.agent_workspace_header == null
  ' "$reports" >/dev/null
}
check_lane_label project alpha
check_lane_label repo alpha
check_lane_label a alpha
check_lane_label checkout alpha
check_lane_label workspace alpha
check_lane_label 'Feature A' 'Feature A'
# An ancestor directory name is not a label Herdr derives.
check_lane_label src src

# The lane owner is the first eligible lead, wherever it sits in the workspace;
# no agent of a lane workspace gets the workspace header.
jq -n '{result: {snapshot: {
  agents: [
    {workspace_id: "w9", pane_id: "early", agent: "claude", name: "worker-early", tokens: {}, agent_status: "idle"},
    {workspace_id: "w9", pane_id: "owner", agent: "claude", name: "lead-owner", tokens: {}, agent_status: "working"},
    {workspace_id: "w9", pane_id: "second", agent: "claude", name: "lead-second", tokens: {}, agent_status: "idle"}
  ],
  workspaces: [{workspace_id: "w9", label: "Lane label"}]
}}}' >"$test_dir/lane-owner.json"
: >"$REPORT_LOG"
SNAPSHOT_FILE="$test_dir/lane-owner.json" "$display_bin" --all
parse_reports
jq -e '
  map([.pane, .tokens.agent_workspace_header, (.tokens.agent_lead // .tokens.agent_worker)]) == [
    ["early", null, "\u200b    – early"],
    ["owner", null, "\u200b  ▶ Lane label"],
    ["second", null, "\u200b  ◇ second"]
  ]
' "$reports" >/dev/null

# A root checkout can share one header with its family when their labels match.
jq '.result.snapshot.agents |= map(select(.workspace_id == "w0"))' \
  "$SNAPSHOT_FILE" >"$test_dir/root.json"
: >"$REPORT_LOG"
SNAPSHOT_FILE="$test_dir/root.json" "$display_bin" --all
parse_reports
jq -e '
  .[0].tokens.agent_repository_header == "project"
  and .[0].tokens.agent_workspace_header == null
  and .[0].tokens.agent_lead == "\u200b▶ root"
  and .[1].tokens.agent_worker == "\u200b    ✓ child"
' "$reports"

jq '.result.snapshot.agents[0].name = ("n" * 100)' "$SNAPSHOT_FILE" >"$test_dir/next.json"
mv "$test_dir/next.json" "$SNAPSHOT_FILE"
: >"$REPORT_LOG"
"$display_bin" --all
parse_reports
jq -e '.[0].tokens | (.agent_display | length) == 80 and (.agent_lead | length) == 80' "$reports"

printf 'Agent display fixtures passed.\n'
