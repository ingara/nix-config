return {
  "neovim/nvim-lspconfig",
  ---@class PluginLspOpts
  opts = {
    ---@type lspconfig.options
    servers = {
      biome = {},
      -- Use nixd instead of nil_ls (LazyVim's nix extra default)
      nixd = {},
      nil_ls = {
        mason = false, -- Disable Mason auto-install, use system nixd instead
      },
    },
    inlay_hints = { enabled = false },
  },
}
