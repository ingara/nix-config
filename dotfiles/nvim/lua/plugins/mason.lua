return {
  -- Override LazyVim's biome config to add prettier fallback
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters = opts.formatters or {}
      opts.formatters.prettier = { require_cwd = true }

      -- Add prettier as fallback for all biome-supported filetypes
      for _, ft in ipairs({ "javascript", "javascriptreact", "typescript", "typescriptreact", "vue", "css", "json", "jsonc" }) do
        opts.formatters_by_ft[ft] = { "biome", "prettier", stop_after_first = true }
      end
    end,
  },
}
