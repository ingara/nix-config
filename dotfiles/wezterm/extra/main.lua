local wezterm = require("wezterm")
local smart_splits = wezterm.plugin.require("https://github.com/mrjones2014/smart-splits.nvim")
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
config.window_background_opacity = 0.95
config.send_composed_key_when_left_alt_is_pressed = true

config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 1000 }
config.keys = {
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
	{
		key = "LeftArrow",
		mods = "CTRL",
		action = wezterm.action.AdjustPaneSize({ "Left", 5 }),
	},
	{
		key = "DownArrow",
		mods = "CTRL",
		action = wezterm.action.AdjustPaneSize({ "Down", 5 }),
	},
	{ key = "UpArrow", mods = "CTRL", action = wezterm.action.AdjustPaneSize({ "Up", 5 }) },
	{
		key = "RightArrow",
		mods = "CTRL",
		action = wezterm.action.AdjustPaneSize({ "Right", 5 }),
	},
	{ mods = "CTRL", key = ",", action = wezterm.action.MoveTabRelative(-1) },
	{ mods = "CTRL", key = ".", action = wezterm.action.MoveTabRelative(1) },
}

smart_splits.apply_to_config(config, {
	-- the default config is here, if you'd like to use the default keys,
	-- you can omit this configuration table parameter and just use
	-- smart_splits.apply_to_config(config)

	-- directional keys to use in order of: left, down, up, right
	direction_keys = { "h", "j", "k", "l" },
	-- modifier keys to combine with direction_keys
	modifiers = {
		move = "CTRL", -- modifier to use for pane movement, e.g. CTRL+h to move left
		resize = "META", -- modifier to use for pane resize, e.g. META+h to resize to the left
	},
})

return config
