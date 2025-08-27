{ configPath }:
{ config, lib, ... }:

let
  dots = {
    "yabai" = "yabai";
    "skhd/skhdrc" = "skhdrc";
    "lazygit/config.yml" = "lazygit.yml";
    "nvim" = "nvim";
    "ghostty" = "ghostty";
    "zellij" = "zellij";
    "alacritty" = "alacritty";
    "sketchybar" = "sketchybar";
    "wezterm/extra" = "wezterm/extra";
    "git/extra" = "git-extra";
  };

  symlink = key: value: {
    source = config.lib.file.mkOutOfStoreSymlink "${configPath}/dotfiles/${value}";
  };
in
{
  xdg.configFile = lib.mapAttrs symlink dots;
}
