return {
  "shellRaining/hlchunk.nvim",
  enabled = false,
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    chunk = { enable = true, use_treesitter = true },
    indent = { enable = false },
    blank = { enable = true },
    line_num = { enable = true, use_treesitter = true },
  },
}
