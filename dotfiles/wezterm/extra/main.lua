local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- https://github.com/wez/wezterm/issues/5990#issuecomment-2305416553
config.front_end = "WebGpu"

config.font = wezterm.font("ZedMono Nerd Font")
-- config.font = wezterm.font("CaskaydiaCove Nerd Font")
-- config.font = wezterm.font("Hack Nerd Font")
-- config.font = wezterm.font("VictorMono Nerd Font")
config.font_size = 13
config.color_scheme = "Catppuccin Macchiato"
config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
config.window_background_opacity = 1
config.send_composed_key_when_left_alt_is_pressed = true

config.enable_kitty_keyboard = true

config.leader = { key = "b", mods = "CTRL", timeout_milliseconds = 1000 }
config.keys = {
	{ key = "h", mods = "CTRL|SHIFT", action = wezterm.action.DisableDefaultAssignment },
	{ key = "k", mods = "CTRL|SHIFT", action = wezterm.action.DisableDefaultAssignment },
	{ key = "l", mods = "CTRL|SHIFT", action = wezterm.action.DisableDefaultAssignment },
	{
		key = "x",
		mods = "LEADER",
		action = wezterm.action.CloseCurrentPane({ confirm = true }),
	},
	{
		key = "r",
		mods = "LEADER",
		action = wezterm.action.RotatePanes("Clockwise"),
	},
	{
		key = "|",
		mods = "LEADER",
		action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }),
	},
	{
		key = "-",
		mods = "LEADER",
		action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }),
	},
	{ mods = "CTRL", key = ",", action = wezterm.action.MoveTabRelative(-1) },
	{ mods = "CTRL", key = ".", action = wezterm.action.MoveTabRelative(1) },
}

return config
