-- Mode-aware cursor / cursorline coloring for reactive.nvim, driven by
-- the base16 palette in `theme.lua` (Nix-generated). Replaces the
-- catppuccin-specific reactive presets we used to load.
--
-- Live-editable: change mode → base16 slot mappings here and reload.
-- The palette itself follows myOptions.theme.scheme, so accent colors
-- adapt automatically when the scheme changes.

local c = require("theme").colors

return {
  builtin = {
    cursorline = true,
    cursor = true,
    modemsg = true,
  },
  configs = {
    base16_cursor = {
      name = "base16_cursor",
      modes = {
        n = { -- Normal
          hl = {
            Cursor = { bg = c.base0D, fg = c.base00 },
            CursorLine = { bg = c.base01 },
            ModeMsg = { fg = c.base0D },
          },
        },
        i = { -- Insert
          hl = {
            Cursor = { bg = c.base0B, fg = c.base00 },
            CursorLine = { bg = c.base01 },
            ModeMsg = { fg = c.base0B },
          },
        },
        v = { -- Visual
          hl = {
            Cursor = { bg = c.base0E, fg = c.base00 },
            CursorLine = { bg = c.base01 },
            ModeMsg = { fg = c.base0E },
          },
        },
        V = { -- Visual Line
          hl = {
            Cursor = { bg = c.base0E, fg = c.base00 },
            CursorLine = { bg = c.base01 },
            ModeMsg = { fg = c.base0E },
          },
        },
        c = { -- Command
          hl = {
            Cursor = { bg = c.base0A, fg = c.base00 },
            CursorLine = { bg = c.base01 },
            ModeMsg = { fg = c.base0A },
          },
        },
        R = { -- Replace
          hl = {
            Cursor = { bg = c.base08, fg = c.base00 },
            CursorLine = { bg = c.base01 },
            ModeMsg = { fg = c.base08 },
          },
        },
        t = { -- Terminal
          hl = {
            Cursor = { bg = c.base0C, fg = c.base00 },
            CursorLine = { bg = c.base01 },
            ModeMsg = { fg = c.base0C },
          },
        },
      },
    },
  },
}
