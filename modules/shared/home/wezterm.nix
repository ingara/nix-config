# Terminal emulators.
#
# - `programs.wezterm`  — enabled on hosts that set `myOptions.hasGui`.
#   extraConfig just delegates to the lua bundled via dotfiles.
# - `programs.alacritty` — explicitly disabled (kept as a one-line revert
#   path if wezterm regresses on a new OS release).
{ config, lib, ... }:

let
  inherit (config.myOptions) hasGui;
  dots = import ./lib/dotfiles.nix { inherit lib; };
in
{
  # wezterm/extra (clean dir → whole-dir symlink) is the lua tree extraConfig's
  # require('extra.main') loads.
  xdg.configFile = dots.mkDirSymlink {
    inherit config;
    srcRel = "wezterm/extra";
    xdgRel = "wezterm/extra";
  };

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
