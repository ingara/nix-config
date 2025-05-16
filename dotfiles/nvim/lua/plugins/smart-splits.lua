return {
  "mrjones2014/smart-splits.nvim",
  lazy = false,
  keys = {
    {
      "<leader>wr",
      function()
        require("smart-splits").start_resize_mode
      end,
      desc = "Start resize mode",
    },
    -- Moving
    {
      "<C-h>",
      function()
        require("smart-splits").move_cursor_left
      end,
      { desc = "navigate left", silent = true },
    },
    {
      "<C-j>",
      function()
        require("smart-splits").move_cursor_down
      end,
      { desc = "navigate down", silent = true },
    },
    {
      "<C-k>",
      function()
        require("smart-splits").move_cursor_up
      end,
      { desc = "navigate up", silent = true },
    },
    {
      "<C-l>",
      function()
        require("smart-splits").move_cursor_right
      end,
      { desc = "navigate right", silent = true },
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
}
