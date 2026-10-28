# Scrubs one `herdr agent get` reply the same way as scrub-snapshot.jq.
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
.result.agent |= scrub_agent("worker-claude")
