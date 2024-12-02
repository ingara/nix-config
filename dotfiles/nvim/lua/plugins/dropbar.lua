return {
  {
    "Bekaboo/dropbar.nvim",
    enabled = false,
    -- optional, but required for fuzzy finder support
    lazy = false,
    dependencies = {
      "nvim-telescope/telescope-fzf-native.nvim",
    },
    keys = {
      {
        "<leader>db",
        function()
          require("dropbar.api").pick()
        end,
        desc = "Dropbar picker",
      },
    },
  },
}
