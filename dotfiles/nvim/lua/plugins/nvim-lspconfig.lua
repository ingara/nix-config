return {
  "neovim/nvim-lspconfig",
  ---@class PluginLspOpts
  opts = {
    ---@type lspconfig.options
    servers = {
      biome = {},
      -- Use nixd instead of nil_ls (LazyVim's nix extra default)
      nixd = { mason = false },
      nil_ls = {
        enabled = false,
      },
    },
    inlay_hints = { enabled = false },
  },
}
