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

-- Auto-populate SSH domains from ~/.ssh/config (no hardcoded hostnames)
local ssh_domains = wezterm.default_ssh_domains()
for _, domain in ipairs(ssh_domains) do
	domain.multiplexing = "None"
	domain.assume_shell = "Posix"
end
config.ssh_domains = ssh_domains

wezterm.on("format-tab-title", function(tab)
	local domain = tab.active_pane.domain_name
	local title = tab.active_pane.title
	if domain ~= "local" then
		local host = domain:match("^SSH:(.+)$") or domain:match("^SSHMUX:(.+)$") or domain
		return "[" .. host .. "] " .. title
	end
	return title
end)

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
	{ key = "s", mods = "LEADER", action = wezterm.action.ShowLauncherArgs({ flags = "FUZZY|DOMAINS" }) },
}

return config
