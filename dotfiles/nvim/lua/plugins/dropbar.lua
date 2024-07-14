return {
  {
    "Bekaboo/dropbar.nvim",
    -- optional, but required for fuzzy finder support
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
