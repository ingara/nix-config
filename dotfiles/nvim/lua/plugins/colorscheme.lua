-- All candidate colorscheme plugins are installed; only the one whose
-- name matches `theme.colorscheme` actually renders. The active scheme
-- comes from Nix (myOptions.theme.scheme → ~/.config/nvim/lua/theme.lua).
local theme = require("theme")

return {
  { "catppuccin/nvim", name = "catppuccin", opts = { transparent_background = true } },
  { "rose-pine/neovim", name = "rose-pine" },
  { "folke/tokyonight.nvim" },
  { "rebelot/kanagawa.nvim" },

  -- Mode-aware cursor; preset config is base16-driven, see theme_reactive.lua.
  {
    "rasulomaroff/reactive.nvim",
    opts = function()
      return require("theme_reactive")
    end,
  },

  -- LazyVim drives `:colorscheme` from theme.lua.
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = theme.colorscheme,
    },
  },
}
