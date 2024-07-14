return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    -- priority = 1000,
    lazy = true,
    opts = {
      flavour = "macchiato",
      transparent_background = true,
      show_end_of_buffer = true,
      -- dim_inactive = {
      --   enabled = true, -- dims the background color of inactive window
      --   shade = "dark",
      --   percentage = 0.15, -- percentage of the shade to apply to the inactive window
      -- },
    },
  },
  {
    "folke/tokyonight.nvim",
    lazy = true,
    opts = { style = "moon" },
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
