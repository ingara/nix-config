return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    opts = {
      flavour = "macchiato",
      transparent_background = true,
      dim_inactive = {
        enabled = true, -- dims the background color of inactive window
        shade = "dark",
        percentage = 0.15, -- percentage of the shade to apply to the inactive window
      },
    },
  },

  -- {
  --   "catppuccin/nvim",
  --   name = "catppuccin",
  --   -- priority = 1000,
  --   lazy = true,
  --   opts = {
  --     flavour = "macchiato",
  --     transparent_background = true,
  --     show_end_of_buffer = true,
  --     dim_inactive = {
  --       enabled = true, -- dims the background color of inactive window
  --       shade = "dark",
  --       percentage = 0.15, -- percentage of the shade to apply to the inactive window
  --     },
  --     integrations = {
  --       dropbar = {
  --         enabled = true,
  --         color_mode = true,
  --       },
  --       harpoon = true,
  --       neotree = true,
  --       noice = true,
  --       lsp_trouble = true,
  --       which_key = true,
  --       indent_blankline = {
  --         enabled = true,
  --         scope_color = "pink",
  --         colored_indent_levels = true,
  --       },
  --     },
  --   },
  -- },
  -- {
  --   "nvim-lualine/lualine.nvim",
  --   opts = {
  --     options = {
  --       theme = "catppuccin",
  --     },
  --   },
  -- },
  -- {
  --   "folke/tokyonight.nvim",
  --   lazy = true,
  --   opts = { style = "moon" },
  -- },
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
