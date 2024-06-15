return {
  "nyngwang/NeoZoom.lua",
  config = function()
    require("neo-zoom").setup({})
  end,
  keys = {
    {
      "<leader>wz",
      "<cmd>NeoZoomToggle<cr>",
      desc = "Zoom split",
      silent = true,
      nowait = true,
    },
  },
}
