return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        files = {
          hidden = true,
        },
      },
      cwd = function()
        return Snacks.git.get_root() or vim.uv.cwd()
      end,
    },
  },
}