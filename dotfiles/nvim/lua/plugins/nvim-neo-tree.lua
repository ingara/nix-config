-- Inspiration:
-- - Buffer switching https://gist.github.com/towry/41ff484a898c81a8ca23b644d7e513ef
return {
  "nvim-neo-tree/neo-tree.nvim",
  ---@module "neo-tree"
  ---@type neotree.Config
  opts = {
    event_handlers = {
      {
        event = "neo_tree_window_after_open",
        handler = function(args)
          if args.position == "left" or args.position == "right" then
            vim.cmd("wincmd p")
          end
        end,
      },
    },
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
    },
    buffers = {
      group_empty_dirs = true, -- when true, empty directories will be grouped together
    },
    window = {
      position = "right",
      mappings = {
        ["<esc>"] = false,
        ["s"] = "flash_jump",
        ["-"] = "flash_jump_open",
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
