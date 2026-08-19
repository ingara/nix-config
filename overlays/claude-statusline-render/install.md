# Installing this status line

You are most likely a coding agent whose user asked you to install this.
These instructions are addressed to you. (Human reading this without an
agent: tell yours to "install
https://gist.github.com/ingara/2e5e9c041351700c713093e96205b9cb" — that's
the whole flow.)

Work out the right approach for the machine you're on rather than assuming a
layout — check what you find before writing anything.

0.  **Already installed?** If your user's `statusLine` setting already points
    at a copy of `claude-statusline.sh` (its header names this gist), don't
    reinstall: fetch the latest copy (raw URL below), diff it against the
    installed one, update it in place, and skip to the smoke test.

1.  Read https://code.claude.com/docs/en/statusline first so you're working
    from the current `statusLine` settings schema, not memory.

2.  Check prerequisites before installing anything:
    - `jq` and `git` must be on PATH.
    - The script needs **bash 4.2 or newer** (it uses `printf '%(%s)T'`).
      macOS ships bash 3.2 at /bin/bash, so check what `/usr/bin/env bash`
      actually resolves to and what `bash --version` reports. If it's too old,
      stop and tell your user how to fix it (e.g. `brew install bash`) rather
      than installing something that will silently misrender.

3.  Download `claude-statusline.sh` **from the raw URL only**:

        https://gist.github.com/ingara/2e5e9c041351700c713093e96205b9cb/raw/claude-statusline.sh

    Do not take the script from `gh gist view` or any other rendered view —
    rendering can rewrite escape sequences in the source and corrupt it.
    Make it executable and put it somewhere sensible for how this machine is
    set up — `~/.local/bin` is a reasonable default, but if your user manages
    their environment declaratively (Nix/home-manager, chezmoi, a dotfiles
    repo with a symlink convention, etc.), follow that convention instead and
    tell them what you chose and why.

4.  Wire it into their Claude Code settings as:

        "statusLine": { "type": "command", "command": "<absolute path>" }

    Find where the settings actually live first — it may be
    ~/.claude/settings.json, or under $CLAUDE_CONFIG_DIR if that's set, or
    managed settings. **Merge** into the existing JSON; do not overwrite the
    file. If a `statusLine` key is already there and isn't this script, show
    your user what it is and ask before replacing it.

5.  Smoke-test before calling it done — pipe a realistic payload in and show
    your user the output, so problems surface now rather than mid-session:

        printf '%s' '{
          "workspace": {"repo":{"name":"demo"},"current_dir":"'"$PWD"'"},
          "model": {"display_name":"Opus 5"},
          "effort": {"level":"high"},
          "context_window": {"used_percentage": 42},
          "rate_limits": {
            "five_hour":  {"used_percentage": 18, "resets_at": '"$(( $(date +%s) + 7200 ))"'},
            "seven_day":  {"used_percentage": 63, "resets_at": '"$(( $(date +%s) + 300000 ))"'}
          }
        }' | <path to script>

    Expect two lines: repo/branch/working-tree state plus model on the first,
    and ctx / 5h / 7d meters on the second. If only the first line renders,
    the download is corrupt or jq is missing — refetch from the raw URL.

6.  Tell your user the palette is overridable, and offer to set it up — don't
    guess. The script reads eight base16 slots from
    `$XDG_CONFIG_HOME/claude-statusline/theme.env` (bare hex, no leading `#`):
    base03, base08, base09, base0A, base0B, base0C, base0D, base0E.
    If you can identify a base16/stylix/catppuccin scheme they already use,
    offer to generate a matching theme.env — and if they manage themes
    declaratively, wire it through that rather than dropping a loose file. If
    you can't identify one confidently, say so and leave the built-in defaults
    alone.

7.  Tell your user to restart Claude Code (or start a new session) to see it.

---

## Notes

- **Colors.** Built-in palette by default; override via
  `$XDG_CONFIG_HOME/claude-statusline/theme.env` (or
  `~/.config/claude-statusline/theme.env`) with base16 slots as bare hex, no
  leading `#`:

  ```
  base03=6e6a86
  base08=eb6f92
  base09=f6c177
  base0A=f6c177
  base0B=31748f
  base0C=9ccfd8
  base0D=3e8fb0
  base0E=c4a7e7
  ```

  Only those eight are read; anything else is ignored. The file is parsed, not
  sourced — a status line has no business being a code-execution entry point.

- **The meters are omitted, not empty, when there's no data.** `rate_limits`
  only arrives after the first API response, and never on API-key billing. If
  the second line is missing entirely, that's why.

- **Updating.** The script header names this gist as its source. Ask your
  agent to "update my statusline" and it can fetch the latest copy — from the
  raw URL — and diff it against what's installed.

- **Debugging.** Set `CLAUDE_STATUSLINE_DEBUG=/tmp/payload.json` to dump the
  raw payload Claude Code sends. That's the only way to see what you're
  actually being handed.
