-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- By default `lsp` is before .git
vim.g.root_spec = { { ".git", "lua" }, "lsp", "cwd" }

-- Needed to play nice with bun: https://github.com/oven-sh/bun/issues/8520
vim.o.backupcopy = "yes"
-- vim.o.termguicolors = true
vim.diagnostic.config({
  float = { border = "rounded" },
})
-- vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
--   border = "rounded",
-- })
