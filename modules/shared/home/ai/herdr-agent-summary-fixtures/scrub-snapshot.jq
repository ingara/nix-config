# Keeps three agents and the panes, tabs, workspaces and layouts they belong to,
# replacing every name, path, title and token value with a generic one.
def names: {"0": "lead-omp", "4": "lead-claude", "17": "worker-claude"};
def scrub_agent($name):
  .name = $name
  | .cwd = "/home/user/src/repo" | .foreground_cwd = "/home/user/src/repo"
  | .terminal_title = "title" | .terminal_title_stripped = "title"
  | .agent_session.value |= (if . | startswith("/")
      then "/home/user/.omp/agent/sessions/-home-user-src-repo/2026-01-01T00-00-00-000Z_session.jsonl"
      else "00000000-0000-4000-8000-000000000000" end)
  | .tokens |= with_entries(.value = (
      if .key == "agent_summary" then "\u200b  Example summary"
      elif .key == "agent_summary_stale" then "\u200b  \u25cc Example summary"
      else "example" end));
.result.snapshot as $s
| [0, 4, 17] as $keep
| [$keep[] as $i | $s.agents[$i] | scrub_agent(names[$i | tostring])] as $agents
| ($agents | map(.pane_id)) as $pane_ids
| ($agents | map(.tab_id)) as $tab_ids
| ($agents | map(.workspace_id)) as $ws_ids
| .result.snapshot = ($s
  | .agents = $agents
  | .focused_pane_id = $pane_ids[0] | .focused_tab_id = $tab_ids[0] | .focused_workspace_id = $ws_ids[0]
  | .panes = [.panes[] | select(.pane_id as $p | $pane_ids | index($p))
      | (.pane_id) as $p | ($agents[] | select(.pane_id == $p)) as $a
      | .cwd = $a.cwd | .foreground_cwd = $a.foreground_cwd
      | .terminal_title = $a.terminal_title | .terminal_title_stripped = $a.terminal_title_stripped
      | .tokens = $a.tokens | .agent_session = $a.agent_session | (if has("name") then .name = $a.name else . end)]
  | .tabs = [.tabs[] | select(.tab_id as $t | $tab_ids | index($t)) | .label = "tab"]
  | .workspaces = [.workspaces[] | select(.workspace_id as $w | $ws_ids | index($w))
      | .label = "workspace" | (if .worktree != null then .worktree |= (if type == "object" then (with_entries(.value |= (if type == "string" then "/home/user/src/repo" else . end)) | .repo_name = "repo") else . end) else . end)]
  | .layouts = [.layouts[] | select(.tab_id as $t | $tab_ids | index($t))
      | .panes |= map(select(.pane_id as $p | $pane_ids | index($p)) // .)])
