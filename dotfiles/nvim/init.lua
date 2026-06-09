-- Store lazyvim.json in data dir so config dir can be read-only
vim.g.lazyvim_json = vim.fn.stdpath("data") .. "/lazyvim.json"

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
