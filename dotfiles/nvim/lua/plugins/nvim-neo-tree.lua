-- Inspiration:
-- - Buffer switching https://gist.github.com/towry/41ff484a898c81a8ca23b644d7e513ef
return {
  "nvim-neo-tree/neo-tree.nvim",
  -----@module "neo-tree"
  -----@type neotree.Config
  opts = {
    filesystem = {
      filtered_items = {
        hide_dotfiles = false,
        hide_gitignored = false,
      },
    },
    commands = {
      reveal_node_in_tree = function(state)
        local node = state.tree:get_node()
        if (node.type == "directory" or node:has_children()) and node:is_expanded() then
          return
        end

        require("neo-tree.command").execute({
          source = "filesystem",
          position = state.current_position,
          action = "focus",
          reveal_file = node.path,
        })
      end,
      flash_jump = function()
        require("flash").jump({
          search = {
            mode = "search",
            max_length = 0,
            exclude = {
              function(win)
                return vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= "neo-tree"
              end,
            },
          },
          label = {
            after = { 0, 1 },
            before = false,
            style = "overlay",
            reuse = "all",
          },
          pattern = "\\.[a-z0-9]\\+\\s#\\d\\+\\s",
          action = function(match, state)
            vim.api.nvim_win_call(match.win, function()
              vim.api.nvim_win_set_cursor(match.win, { match.pos[1], 0 })
            end)
            state:restore()
          end,
          highlight = {
            backdrop = false,
            matches = false,
            groups = {
              match = "DiffAdd",
              current = "DiffAdd",
              label = "DiffAdd",
            },
          },
        })
      end,
      flash_jump_open = function(tree_state)
        require("flash").jump({
          labels = "asdfghjklwertyuiopzxcvbnm1234567890",
          search = {
            mode = "search",
            max_length = 0,
            exclude = {
              function(win)
                return vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= "neo-tree"
              end,
            },
          },
          label = {
            after = { 0, 1 },
            before = false,
            style = "overlay",
            reuse = "lowercase",
          },
          action = function(match, state)
            state:restore()
            vim.schedule(function()
              if not vim.api.nvim_win_is_valid(match.win) then
                return
              end
              vim.api.nvim_win_call(match.win, function()
                vim.api.nvim_win_set_cursor(match.win, { match.pos[1], 0 })
                ---@diagnostic disable-next-line: missing-parameter
                require("neo-tree.sources.common.commands").open(tree_state)
              end)
            end)
          end,
          pattern = "\\.[a-z0-9]\\+\\s#\\d\\+\\s",
          highlight = {
            backdrop = false,
            matches = false,
            groups = {
              match = "DiffDelete",
              current = "DiffDelete",
              label = "DiffDelete",
            },
          },
        })
      end,
      avante_add_files = function(state)
        local avante_ok, avante = pcall(require, "avante")
        if not avante_ok then
          vim.notify("Avante is not available", vim.log.levels.WARN)
          return
        end

        local node = state.tree:get_node()
        local filepath = node:get_id()
        local utils_ok, avante_utils = pcall(require, "avante.utils")
        if not utils_ok then
          vim.notify("Avante utils not available", vim.log.levels.WARN)
          return
        end
        
        local relative_path = avante_utils.relative_path(filepath)
        local sidebar = avante.get()

        local open = sidebar:is_open()
        -- ensure avante sidebar is open
        if not open then
          require("avante.api").ask()
          sidebar = avante.get()
        end

        sidebar.file_selector:add_selected_file(relative_path)

        -- remove neo tree buffer
        if not open then
          sidebar.file_selector:remove_selected_file("neo-tree filesystem [1]")
        end
      end,
    },
    buffers = {
      group_empty_dirs = true, -- when true, empty directories will be grouped together
    },
    window = {
      mappings = {
        ["<esc>"] = false,
        ["s"] = "flash_jump",
        ["-"] = "flash_jump_open",
        ["A"] = "avante_add_files",
      },
    },
  },
  keys = {
    {
      "-",
      "<cmd>Neotree source=buffers float reveal action=focus<cr>",
      desc = "Open buffers",
    },
  },
}
