return {
  "folke/snacks.nvim",
  opts = {
    terminal = {
      win = {
        position = "float",
        width = 0.8,
        height = 0.8,
        border = "rounded",
      },
    },
    picker = {
      sources = {
        files = {
          hidden = true,
          config = function(opts)
            -- Use git root as cwd if available, fall back to current directory
            opts.cwd = Snacks.git.get_root() or vim.uv.cwd()
            return opts
          end,
        },
      },
    },
  },
}
