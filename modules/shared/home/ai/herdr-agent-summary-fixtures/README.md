# agent-summary fixtures

Captured from the locked tools on aarch64-linux on 2026-10-27. Parsing in
`herdr-agent-summary.py` is tested against these files.

## Claude Code 2.1.310

`claude-reply.json` is the unmodified stdout of one summary call, made with the
plugin's flags, environment isolation and system prompt from an empty working
directory:

```sh
printf '%s\n' "$digest" | env -u <HERDR_*, CLAUDECODE*, CLAUDE_CODE_*> \
  CLAUDE_CONFIG_DIR=<config dir> claude -p --safe-mode --model haiku --tools "" \
  --no-session-persistence --disable-slash-commands \
  --settings '{"disableAllHooks":true}' --system-prompt "$system_prompt" \
  --output-format json
```

`$digest` was a synthetic transcript digest about login retry work, the same
shape the plugin renders.

`claude-error.json` is the unmodified stdout of the same command with
`--model no-such-model` and system prompt `x`; it exited with status 1.

## Herdr 0.9.5 (protocol 22)

- `herdr-snapshot.json`: `herdr api snapshot`, reduced by `scrub-snapshot.jq`
  to three agents and the panes, tabs, workspaces and layouts they belong to,
  with names, paths, titles, session values and token values replaced. Field
  names, types and structure are as captured.
- `herdr-agent-get.json`: `herdr agent get <pane>`, scrubbed by
  `scrub-agent.jq` the same way.
- `herdr-agent-get-missing.stderr`: stderr of `herdr agent get w0:p0` for a
  pane that does not exist. Stdout was empty and the exit status 1.
