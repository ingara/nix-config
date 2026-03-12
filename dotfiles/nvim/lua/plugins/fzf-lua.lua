return {
  "ibhagwan/fzf-lua",
  opts = {
    fzf_opts = { ["--cycle"] = true },
  },
  keys = {
    {
      "<C-p>",
      function()
        require("fzf-lua").lsp_live_workspace_symbols({
          regex_filter = symbols_filter,
        })
      end,
      desc = "Goto Symbol (Workspace)",
    },
  },
}
