{
  configPath,
  wmBackend ? "yabai",
}:
{ config, lib, ... }:

let
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
    "claude" = "claude";
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
    source = config.lib.file.mkOutOfStoreSymlink "${configPath}/dotfiles/${value}";
  };
in
{
  xdg.configFile = lib.mapAttrs symlink dots;
}
