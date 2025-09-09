return {
  "saghen/blink.cmp",

  -- dependencies = {
  --   "Kaiser-Yang/blink-cmp-avante",
  -- },
  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
    sources = {
      -- adding any nvim-cmp sources here will enable them
      -- with blink.compat
      -- compat = {},
      default = { "lsp", "path", "buffer" },
      -- cmdline = {},
      -- providers = {
      --   avante = {
      --     name = "avante",
      --     module = "blink-cmp-avante",
      --     kind = "Avante",
      --     async = true,
      --     opts = {
      --       -- options for blink-cmp-avante
      --     },
      --   },
      -- },
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
      -- https://github.com/LazyVim/LazyVim/issues/61852
      ["<Tab>"] = {
        require("blink.cmp.keymap.presets").get("super-tab")["<Tab>"][1],
        require("lazyvim.util.cmp").map({ "snippet_forward", "ai_accept" }),
        "fallback",
      },
    },
  },
}
