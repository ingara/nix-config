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

-- VSCode keymaps
if vim.g.vscode then
  -- Navigation: Pane movement
  map("n", "<C-h>", function()
    require("vscode").action("workbench.action.navigateLeft")
  end, { desc = "Go left" })

  map("n", "<C-j>", function()
    require("vscode").action("workbench.action.navigateDown")
  end, { desc = "Go down" })

  map("n", "<C-k>", function()
    require("vscode").action("workbench.action.navigateUp")
  end, { desc = "Go up" })

  map("n", "<C-l>", function()
    require("vscode").action("workbench.action.navigateRight")
  end, { desc = "Go right" })

  -- LSP and Editor Actions
  map("n", "<leader>la", function()
    require("vscode").action("editor.action.quickFix")
  end, { desc = "Quick Fix" })

  map("n", "<leader>ld", function()
    require("vscode").action("editor.action.showHover")
  end, { desc = "Show Hover" })

  map("n", "<leader>lF", function()
    require("vscode").action("editor.action.formatDocument")
  end, { desc = "Format Document" })

  -- AI chat and agent actions
  map("n", "<leader>ic", function()
    require("vscode").action("workbench.panel.chat.view.focus")
  end, { desc = "Focus Chat Panel" })

  map("n", "<leader>ia", function()
    require("vscode").action("composerMode.agent")
  end, { desc = "AI Agent" })

  -- WhichKey (if using WhichKey extension)
  map("n", "<leader>", function()
    require("vscode").action("whichkey.show")
  end, { desc = "Show WhichKey" })
end
