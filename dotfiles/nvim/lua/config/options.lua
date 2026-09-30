-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- By default `lsp` is before .git
vim.g.root_spec = { { ".git", "lua" }, "lsp", "cwd" }

-- Disable trouble in lualine since we're using dropbar
-- vim.g.trouble_lualine = false

-- Needed to play nice with bun: https://github.com/oven-sh/bun/issues/8520
vim.o.backupcopy = "yes"
-- vim.o.termguicolors = true
vim.diagnostic.config({
  float = { border = "rounded" },
})

vim.opt.wrap = true

vim.g.lazyvim_prettier_needs_config = true

-- Force OSC 52 clipboard in SSH and Herdr sessions instead of relying on
-- capability detection through nested terminals. Paste uses the internal
-- register to avoid the ~10s freeze from terminals that don't support OSC 52
-- reads — use Cmd+V instead.
if vim.env.SSH_TTY or vim.env.HERDR_ENV == "1" then
  vim.opt.clipboard = "unnamedplus"

  local function paste()
    return { vim.fn.split(vim.fn.getreg(""), "\n"), vim.fn.getregtype("") }
  end

  vim.g.clipboard = {
    name = "OSC 52",
    copy = {
      ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
      ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
    },
    paste = {
      ["+"] = paste,
      ["*"] = paste,
    },
  }
end
