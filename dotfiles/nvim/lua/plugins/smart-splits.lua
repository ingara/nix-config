return {
  {
    "mrjones2014/smart-splits.nvim",
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
        { desc = "navigate left" },
      },
      {
        "<C-j>",
        function()
          require("smart-splits").move_cursor_down()
        end,
        mode = { "i", "n", "v" },
        { desc = "navigate down" },
      },
      {
        "<C-k>",
        function()
          require("smart-splits").move_cursor_up()
        end,
        mode = { "i", "n", "v" },
        { desc = "navigate up" },
      },
      {
        "<C-l>",
        function()
          require("smart-splits").move_cursor_right()
        end,
        mode = { "i", "n", "v" },
        { desc = "navigate right" },
      },
      -- Resizing
      {
        "<Left>",
        function()
          require("smart-splits").resize_left()
        end,
        { desc = "navigate left", silent = true },
      },
      {
        "<Down>",
        function()
          require("smart-splits").resize_down()
        end,
        { desc = "navigate down", silent = true },
      },
      {
        "<Up>",
        function()
          require("smart-splits").resize_up()
        end,
        { desc = "navigate up", silent = true },
      },
      {
        "<Right>",
        function()
          require("smart-splits").resize_right()
        end,
        { desc = "navigate right", silent = true },
      },
    },
  },
}
