-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local map = vim.keymap.set

-- map("", "<leader>y", '"+y', { desc = "Copy to clipboard in normal, visual, select and operator modes" })
map({ "n", "v", "o" }, "H", "^", { desc = "Start of line" })
map({ "n", "v", "o" }, "L", "g_", { desc = "End of line" })

map({ "n", "v", "o", "x" }, "ø", "[", { remap = true })
map({ "n", "v", "o", "x" }, "æ", "]", { remap = true })
map({ "n", "v", "o", "x" }, "Ø", "{", { remap = true })
map({ "n", "v", "o", "x" }, "Æ", "}", { remap = true })

-- lazygit
map("n", "<C-g>", function()
  Snacks.lazygit({ cwd = LazyVim.root.git() })
end, { desc = "Lazygit (Root Dir)" })

-- LSP
map({ "n", "v" }, "<C-q>", vim.lsp.buf.code_action, { desc = "Code Action" })
