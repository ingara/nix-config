# Terminal emulators.
#
# - `programs.wezterm`  — enabled on hosts that set `myOptions.hasGui`.
#   extraConfig just delegates to the lua bundled via dotfiles.
# - `programs.alacritty` — explicitly disabled (kept as a one-line revert
#   path if wezterm regresses on a new OS release).
{ config, ... }:

let
  inherit (config.myOptions) hasGui;
in
{
  programs.wezterm = {
    enable = hasGui;
    extraConfig = ''
      local config = require('extra.main')
      return config
    '';
  };

  programs.alacritty = {
    enable = false;
  };
}
