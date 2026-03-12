{ config, lib, ... }:

let
  configPath = "${config.home.homeDirectory}/nix-config";
  inherit (config.myOptions.dotfiles) wmBackend;
  mutable = config.myOptions.mutableDotfiles;

  # Base dotfiles (always linked)
  baseDots = {
    "lazygit/config.yml" = "lazygit.yml";
    "nvim" = "nvim";
    "ghostty" = "ghostty";
    "zellij" = "zellij";
    "alacritty" = "alacritty";
    "sketchybar" = "sketchybar";
    "wezterm/extra" = "wezterm/extra";
    "git/extra" = "git-extra";
  };

  # Yabai-specific dotfiles
  yabaiDots = {
    "yabai" = "yabai";
    "skhd/skhdrc" = "skhdrc";
  };

  # AeroSpace-specific dotfiles
  aerospaceDots = {
    "aerospace" = "aerospace";
  };

  # Combine based on selected backend
  dots =
    baseDots
    // (if wmBackend == "yabai" then yabaiDots else { })
    // (if wmBackend == "aerospace" then aerospaceDots else { });

  symlink = key: value: {
    source =
      if mutable then
        config.lib.file.mkOutOfStoreSymlink "${configPath}/dotfiles/${value}"
      else
        ../../dotfiles + "/${value}";
  };
in
{
  options.myOptions.dotfiles = {
    wmBackend = lib.mkOption {
      type = lib.types.enum [
        "yabai"
        "aerospace"
        "none"
      ];
      default = "none";
    };
  };

  config = {
    xdg.configFile = lib.mapAttrs symlink dots;
  };
}
