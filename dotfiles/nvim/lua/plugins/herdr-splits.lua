-- Ctrl+hjkl inside herdr, where smart-splits.lua can't reach.
--
-- The full chain is nvim splits -> herdr panes -> tmux panes. Each layer moves
-- if it can and hands outward if it can't: nvim delegates to herdr here, and
-- herdr's own nav script delegates to tmux (that fall-through is patched in by
-- the herdr-splits package, since upstream assumes herdr is outermost).
--
-- The herdr-side plugin and its Ctrl+hjkl bindings are managed in nix
-- (programs.herdr.splits), not by `herdr plugin install`.
return {
  {
    "lmilojevicc/herdr-splits.nvim",
    -- Exact complement of smart-splits.lua's cond, so only ever one of the two
    -- binds these keys.
    cond = vim.env.HERDR_ENV == "1",
    event = "VeryLazy",
    opts = {
      -- Hand off to tmux at a herdr edge rather than wrapping to the opposite
      -- pane. Keeps this in step with the packaged nav script, which patches the
      -- same default for the case where this config hasn't been written yet.
      nav_at_edge = "stop",
    },
    keys = {
      {
        "<C-h>",
        function()
          require("herdr-splits").move_cursor_left()
        end,
        mode = { "i", "n", "v" },
        desc = "Navigate left",
      },
      {
        "<C-j>",
        function()
          require("herdr-splits").move_cursor_down()
        end,
        mode = { "i", "n", "v" },
        desc = "Navigate down",
      },
      {
        "<C-k>",
        function()
          require("herdr-splits").move_cursor_up()
        end,
        mode = { "i", "n", "v" },
        desc = "Navigate up",
      },
      {
        "<C-l>",
        function()
          require("herdr-splits").move_cursor_right()
        end,
        mode = { "i", "n", "v" },
        desc = "Navigate right",
      },
    },
  },
}
