{ configPath }: { config, lib, ... }:

let
  dots = {
    "yabai/yabairc" = "yabairc";
    "skhd/skhdrc" = "skhdrc";
    "lazygit/config.yml" = "lazygit.yml";
    "nvim" = "nvim";
    "ghostty" = "ghostty";
    "alacritty" = "alacritty";
    "sketchybar" = "sketchybar";
    "wezterm/extra" = "wezterm/extra";
  };

  symlink = key: value: {
    source = config.lib.file.mkOutOfStoreSymlink "${configPath}/dotfiles/${value}";
  };
in
{
  xdg.configFile = lib.mapAttrs symlink dots;
}

