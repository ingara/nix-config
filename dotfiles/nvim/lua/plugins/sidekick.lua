-- Toggle a sidekick CLI tool for the current cwd without going through
-- sidekick's picker. Sidekick's public API (`cli.toggle`/`cli.show`) routes
-- through `State.with`, which falls into a picker when 0 or >1 matches exist.
-- `filter.cwd = true` excludes unstarted tools (M.is requires a session), so
-- the bootstrap case leaks into the picker with no cwd preference.
--
-- We bypass that by computing the current-cwd sid directly, finding any
-- matching session via `Session.sessions()`, and calling `State.attach` — the
-- actual create-or-reattach primitive — with a fresh tool state when none
-- exists. This uses internal modules (`sidekick.cli.session`, `.state`,
-- `sidekick.config`) which are not declared stable; keep an eye on upstream
-- churn and revisit if folke refactors.
local function toggle_cli(name)
  local Session = require("sidekick.cli.session")
  local State = require("sidekick.cli.state")
  local Config = require("sidekick.config")

  local sid = Session.sid({ tool = name })

  -- Look for an existing session for this tool in the current cwd
  local state
  for _, s in pairs(Session.sessions()) do
    if s.sid == sid then
      state = State.get_state(s)
      break
    end
  end

  -- Existing session with a live terminal → toggle visibility only
  if state and state.terminal then
    state.terminal:toggle()
    if state.terminal:is_open() then
      state.terminal:focus()
    end
    return
  end

  -- No session yet → build a fresh state from the tool config
  if not state then
    local tool = Config.get_tool(name)
    if not tool then
      vim.notify("Sidekick tool not found: " .. name, vim.log.levels.ERROR)
      return
    end
    state = { tool = tool, installed = true }
  end

  -- Attach: creates the session on first launch, or reattaches when the
  -- session exists but its terminal doesn't (e.g. after a mux detach)
  State.attach(state, { show = true, focus = true })
end

return {
  "folke/sidekick.nvim",
  opts = {
    cli = {
      mux = {
        backend = "zellij",
        enabled = true,
      },
      tools = {
        claude_resume = { cmd = { "claude", "--resume" } },
      },
    },
  },
  keys = {
    {
      "<leader>ac",
      function()
        toggle_cli("claude")
      end,
      desc = "Sidekick Claude (cwd)",
    },
    {
      "<leader>ar",
      function()
        toggle_cli("claude_resume")
      end,
      desc = "Sidekick Claude Resume (cwd)",
    },
    {
      "<leader>as",
      function()
        require("sidekick.cli").send({ selection = true })
      end,
      mode = { "v" },
      desc = "Sidekick Send Selection",
    },
  },
}
