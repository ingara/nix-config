return {
  "neovim/nvim-lspconfig",
  ---@class PluginLspOpts
  opts = {
    ---@type lspconfig.options
    servers = {
      biome = {},
    },
    inlay_hints = { enabled = false },
  },
}
