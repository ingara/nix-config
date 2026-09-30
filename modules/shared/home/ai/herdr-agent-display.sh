#!/usr/bin/env bash

set -euo pipefail

herdr_bin="${HERDR_BIN_PATH:-herdr}"
mode="${1:---all}"
lead_prefixes="${HERDR_AGENT_DISPLAY_LEAD_PREFIXES:-$lead_prefixes}"
worker_prefixes="${HERDR_AGENT_DISPLAY_WORKER_PREFIXES:-$worker_prefixes}"
plain_leads="${HERDR_AGENT_DISPLAY_PLAIN_LEADS:-$plain_leads}"
title_rows="${HERDR_AGENT_DISPLAY_TITLE_ROWS:-$title_rows}"
group_gap="${HERDR_AGENT_DISPLAY_GROUP_GAP:-$group_gap}"

case "$mode" in
--all)
  clear=0
  ;;
--clear)
  clear=1
  ;;
*)
  printf 'usage: herdr-agent-display [--all|--clear]\n' >&2
  exit 2
  ;;
esac

refresh_all() {
  local snapshot seq now
  local -a names values args

  seq="${EPOCHREALTIME/./}"
  if ! snapshot="$("$herdr_bin" api snapshot 2>/dev/null)"; then
    return 0
  fi
  now="${HERDR_AGENT_DISPLAY_NOW:-$EPOCHSECONDS}"
  names=(
    agent_display
    agent_repository_header
    agent_workspace_header
    agent_lead
    agent_lead_quiet
    agent_worker
    agent_worker_quiet
    agent_title
    agent_group_gap
    agent_primary
    agent_primary_old
    agent_primary_stale
    agent_secondary
    agent_activity
  )

  while IFS= read -r -d '' pane_id &&
    IFS= read -r -d '' agent &&
    IFS= read -r -d '' display &&
    IFS= read -r -d '' repository_header &&
    IFS= read -r -d '' workspace_header &&
    IFS= read -r -d '' lead &&
    IFS= read -r -d '' lead_quiet &&
    IFS= read -r -d '' worker &&
    IFS= read -r -d '' worker_quiet &&
    IFS= read -r -d '' title &&
    IFS= read -r -d '' group_gap_row &&
    IFS= read -r -d '' primary &&
    IFS= read -r -d '' primary_old &&
    IFS= read -r -d '' primary_stale &&
    IFS= read -r -d '' secondary &&
    IFS= read -r -d '' activity; do
    values=(
      "$display" "$repository_header" "$workspace_header"
      "$lead" "$lead_quiet" "$worker" "$worker_quiet" "$title" "$group_gap_row"
      "$primary" "$primary_old" "$primary_stale" "$secondary" "$activity"
    )
    args=(
      pane report-metadata "$pane_id"
      --source local.agent-display
      --agent "$agent"
      --seq "$seq"
    )
    for index in "${!names[@]}"; do
      if [ -n "${values[$index]}" ]; then
        args+=(--token "${names[$index]}=${values[$index]}")
      else
        args+=(--clear-token "${names[$index]}")
      fi
    done
    "$herdr_bin" "${args[@]}" >/dev/null || true
  done < <(
    jq -jn \
      --argjson response "$snapshot" \
      --argjson clear "$clear" \
      --argjson now "$now" \
      --argjson lead_prefixes "$lead_prefixes" \
      --argjson worker_prefixes "$worker_prefixes" \
      --argjson plain_leads "$plain_leads" \
      --arg title_rows "$title_rows" \
      --arg group_gap "$group_gap" '
      def clip: .[0:80];
      def workspace($snapshot; $id):
        first($snapshot.workspaces[]? | select(.workspace_id == $id))
          // { workspace_id: $id, label: $id };
      def family_key($workspace):
        if (($workspace.worktree.repo_key // "") != "")
        then "repo:\($workspace.worktree.repo_key)"
        else "workspace:\($workspace.workspace_id)"
        end;
      def prefix($name; $prefixes):
        first($prefixes[] | . as $candidate | select($name | startswith($candidate))) // "";
      def role($name):
        if any($worker_prefixes[]; . as $candidate | $name | startswith($candidate))
        then "worker" else "lead" end;
      # Snapshot status reflects server acknowledgement, not per-TUI seen state.
      def state_mark:
        if . == "working" then "▶"
        elif . == "blocked" then "!"
        elif . == "done" then "✓"
        elif . == "idle" then "–"
        else "?"
        end;
      # Herdr trims token edges; a zero-width prefix preserves indentation.
      def padded($spaces; $text): "\u200b" + (" " * $spaces) + $text | clip;
      def owns_display_token:
        (.tokens // {})
        | has("agent_display")
          or has("agent_repository_header")
          or has("agent_workspace_header")
          or has("agent_lead")
          or has("agent_lead_quiet")
          or has("agent_worker")
          or has("agent_worker_quiet")
          or has("agent_title")
          or has("agent_group_gap")
          or has("agent_primary")
          or has("agent_secondary")
          or has("agent_primary_old")
          or has("agent_primary_stale")
          or has("agent_activity");
      $response.result.snapshot as $snapshot
      | [$snapshot.agents[]? | select((.agent // "") != "")] as $all
      | ($all | to_entries[])
      | .key as $agent_index
      | .value as $agent
      | select(($clear == 0) or ($agent | owns_display_token))
      | if $clear == 1
        then [$agent.pane_id, $agent.agent] + [range(14) | ""]
        else (
          workspace($snapshot; $agent.workspace_id) as $workspace
          | family_key($workspace) as $family_key
          | (if $agent_index == 0
              then true
              else (workspace($snapshot; $all[$agent_index - 1].workspace_id) | family_key(.)) != $family_key
            end) as $first_family_run_agent
          | (if $agent_index == 0
              then true
              else $all[$agent_index - 1].workspace_id != $agent.workspace_id
            end) as $first_workspace_run_agent
          | (if (($agent.name // "") != "")
              then $agent.name
              else $agent.agent
            end) as $name
          | role($name) as $role
          | (if $role == "worker"
              then prefix($name; $worker_prefixes)
              else prefix($name; $lead_prefixes)
            end) as $prefix
          | ($name[($prefix | length):] | if . == "" then $name else . end | clip) as $display
          | (if (($agent.agent_session // null) | type) == "object"
              then ([$agent.agent_session.agent, $agent.agent_session.kind,
                    $agent.agent_session.value] | join(":"))
              else ($agent.terminal_id // "")
            end) as $identity
          | (($agent.agent_session // null) | type) == "object" as $native_identity
          | ($identity != "" and ($identity | contains("|") | not)) as $valid_identity
          | ($agent.state_change_seq // 0) as $state_change_seq
          | ([$identity, ($state_change_seq | tostring), ($agent.agent_status // "unknown"),
              ($now | tostring)] | join("|") | length) as $activity_length
          | ($valid_identity and $activity_length <= 80) as $trackable_identity
          | (($agent.tokens.agent_activity // "") | split("|")) as $previous
          | (($previous | length) == 4 and $trackable_identity
              and (($agent.tokens.agent_activity // "") | length) <= 80
              and $previous[0] == $identity) as $same_agent
          | (try ($previous[3] | tonumber) catch null) as $previous_activity
          | (if $same_agent and $previous_activity != null
              then (if $previous[1] != ($state_change_seq | tostring)
                    and ($previous[2] == "working" or $agent.agent_status == "working")
                then $now
                elif $previous[1] != ($state_change_seq | tostring) and ($native_identity | not)
                then null
                else $previous_activity end)
              elif $agent.agent_status == "working" and $trackable_identity
              then $now
              else null
            end) as $last_activity
          | (if $agent.agent_status == "idle" and $last_activity != null
              then (($now - $last_activity) / 60 | if . < 0 then 0 else . end)
              else null
            end) as $idle_minutes
          | (if (($workspace.worktree.repo_key // "") != "")
              then ($workspace.worktree.repo_name // $workspace.label // $workspace.workspace_id)
              else ""
            end) as $repository
          | ($workspace.label // $workspace.workspace_id) as $workspace_label
          | (if $first_family_run_agent and (($workspace.worktree.repo_key // "") != "")
              then $repository
              else ""
            end) as $repository_label
          | (if $first_workspace_run_agent and $workspace_label != $repository_label
              then $workspace_label
              else ""
            end) as $workspace_group_label
          # Herdr adds two cells to continuation rows; compensate to align headers and marks.
          | (if $workspace_group_label == "" then ""
              else padded((if $repository_label == "" then 2 else 0 end); $workspace_group_label)
            end) as $workspace_header
          | (if $role == "lead" and $prefix != "" and ($plain_leads | index($name)) == null
              and ($agent.agent_status == "idle" or $agent.agent_status == "done")
              then if any($all[]; .workspace_id == $agent.workspace_id
                    and (role((if (.name // "") != "" then .name else .agent end)) == "worker")
                    and (.agent_status == "working" or .agent_status == "blocked"))
                then "⋯" else "◆" end
              else ($agent.agent_status | state_mark)
            end) as $mark
          | (if $repository_label == "" and $workspace_header == "" then 4 else 2 end
              + (if $role == "worker" then 4 else 0 end)) as $indent
          | padded($indent; $mark + " " + $display) as $agent_row
          | (if $title_rows == "all" then
              ($agent.terminal_title_stripped // $agent.terminal_title // ""
                | sub("^(\\p{Greek}|[^\\p{L}\\p{N}[:space:]])[[:space:]]+(>[[:space:]]*|[^\\p{ASCII}\\p{L}\\p{N}[:space:]]+[[:space:]]+)"; "")
                | sub("^([^\\p{L}\\p{N}[:space:]]+[[:space:]]+)+"; "")
                | if . == "" then " " else . end)
              | padded($indent + 2; .)
              else "" end) as $title_row
          | (if $group_gap == "repositories" and ($agent_index + 1) < ($all | length)
              and (workspace($snapshot; $all[$agent_index + 1].workspace_id) as $next
                | family_key($next) != $family_key
                  and ($next.worktree.repo_key // "") != "")
              and any($all[0:$agent_index + 1][]; (workspace($snapshot; .workspace_id).worktree.repo_key // "") != "")
              then "\u200b" else "" end) as $gap_row
          | ([$identity, ($state_change_seq | tostring), ($agent.agent_status // "unknown"),
              ($last_activity // "" | tostring)] | join("|")) as $activity_record
          | (if $valid_identity and ($activity_record | length) <= 80
              then $activity_record else "" end) as $activity
          | [
              $agent.pane_id,
              $agent.agent,
              $display,
              ($repository_label | clip),
              $workspace_header,
              (if $role == "lead" then $agent_row else "" end),
              "",
              (if $role == "worker" and ($idle_minutes == null or $idle_minutes <= 15)
                then $agent_row else "" end),
              (if $role == "worker" and $idle_minutes != null and $idle_minutes > 15
                then $agent_row else "" end),
              $title_row,
              $gap_row,
              "", "", "", "",
              $activity
            ]
        )
        end
      | .[]
      | (., "\u0000")
    '
  )
}

refresh_all
