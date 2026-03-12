return {
  "saghen/blink.cmp",
  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
    sources = {
      default = { "lsp", "path", "buffer" },
    },
    completion = {
      accept = { auto_brackets = { enabled = false } },
      menu = {
        border = "rounded",
      },
      documentation = { window = { border = "rounded" } },
      ghost_text = { enabled = false },
    },
    signature = {
      window = { border = "rounded" },
    },
    keymap = {
      preset = "super-tab",
      ["<Tab>"] = {
        require("blink.cmp.keymap.presets").get("super-tab")["<Tab>"][1],
        require("lazyvim.util.cmp").map({ "snippet_forward", "ai_nes", "ai_accept" }),
        "fallback",
      },
    },
  },
}
