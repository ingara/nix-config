return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    -- Fix for LazyVim bufferline integration issue: https://github.com/LazyVim/LazyVim/issues/6355
    -- Catppuccin changed API from get() to get_theme(), this creates compatibility alias
    opts = function(_, opts)
      local module = require("catppuccin.groups.integrations.bufferline")
      if module then
        module.get = module.get_theme
      end
      return {
        flavour = "macchiato",
        transparent_background = true,
      }
    end,
  },
  {
    "rasulomaroff/reactive.nvim",
    opts = {
      load = { "catppuccin-macchiato-cursor", "catppuccin-macchiato-cursorline" },
    },
  },
  -- Configure LazyVim to load theme
  {
    "LazyVim/LazyVim",
    opts = {
      -- colorscheme = "tokyonight",
      colorscheme = "catppuccin",
    },
  },
}
