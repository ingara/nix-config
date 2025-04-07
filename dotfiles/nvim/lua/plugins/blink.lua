return {
  "saghen/blink.cmp",

  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
    sources = {
      -- adding any nvim-cmp sources here will enable them
      -- with blink.compat
      -- compat = {},
      default = { "lsp", "path", "buffer" },
      -- cmdline = {},
    },
    completion = {
      accept = { auto_brackets = { enabled = false } },
      menu = {
        border = "rounded",
      },
      documentation = { window = { border = "rounded" } },
    },
    signature = {
      window = { border = "rounded" },
    },
    keymap = {
      preset = "super-tab",
    },
  },
}
