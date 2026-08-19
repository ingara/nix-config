return {
  {
    "mrjones2014/smart-splits.nvim",
    -- Inside herdr, herdr-splits.lua owns Ctrl+hjkl instead. smart-splits picks
    -- exactly one multiplexer and would choose herdr the moment HERDR_ENV is
    -- set, leaving no way to reach an outer tmux — and both plugins binding the
    -- same keys would fight. The two conds are exact complements.
    cond = vim.env.HERDR_ENV ~= "1",
    lazy = false,
    opts = {
      -- Enable Zellij integration: move to next tab when at edge of pane
      zellij_move_focus_or_tab = true,
    },
    keys = {
      {
        "<leader>wr",
        function()
          require("smart-splits").start_resize_mode()
        end,
        desc = "Start resize mode",
      },
      -- Moving
      {
        "<C-h>",
        function()
          require("smart-splits").move_cursor_left()
        end,
        mode = { "i", "n", "v" },
        desc = "Navigate left",
      },
      {
        "<C-j>",
        function()
          require("smart-splits").move_cursor_down()
        end,
        mode = { "i", "n", "v" },
        desc = "Navigate down",
      },
      {
        "<C-k>",
        function()
          require("smart-splits").move_cursor_up()
        end,
        mode = { "i", "n", "v" },
        desc = "Navigate up",
      },
      {
        "<C-l>",
        function()
          require("smart-splits").move_cursor_right()
        end,
        mode = { "i", "n", "v" },
        desc = "Navigate right",
      },
      -- Resizing
      {
        "<Left>",
        function()
          require("smart-splits").resize_left()
        end,
        desc = "Resize left",
        silent = true,
      },
      {
        "<Down>",
        function()
          require("smart-splits").resize_down()
        end,
        desc = "Resize down",
        silent = true,
      },
      {
        "<Up>",
        function()
          require("smart-splits").resize_up()
        end,
        desc = "Resize up",
        silent = true,
      },
      {
        "<Right>",
        function()
          require("smart-splits").resize_right()
        end,
        desc = "Resize right",
        silent = true,
      },
    },
  },
}
