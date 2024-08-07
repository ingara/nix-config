-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local map = vim.keymap.set

-- map("", "<leader>y", '"+y', { desc = "Copy to clipboard in normal, visual, select and operator modes" })
map("n", "H", "_", { desc = "Start of line" })
map("n", "L", "g_", { desc = "End of line" })
map("n", "<leader>uz", ":ZenMode<CR>", { desc = "Toggle Zen mode" })

map("n", "ø", "[", { remap = true })
map("n", "æ", "]", { remap = true })
map({ "n", "v" }, "Ø", "{", { remap = true })
map({ "n", "v" }, "Æ", "}", { remap = true })

-- lazygit
map("n", "<C-g>", function()
  LazyVim.lazygit({ cwd = LazyVim.root.git() })
end, { desc = "Lazygit (Root Dir)" })
