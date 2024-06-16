{ configPath }: { config, lib, ... }:

let
  dots = {
    "yabai/yabairc" = "yabairc";
    "skhd/skhdrc" = "skhdrc";
    "lazygit/config.yml" = "lazygit.yml";
    "nvim" = "nvim";
    "alacritty" = "alacritty";
    "sketchybar" = "sketchybar";
  };

mkOutOfStoreSymlink = key: value: {
  source = config.lib.file.mkOutOfStoreSymlink "${configPath}/dotfiles/${value}";
};
in
{
  xdg.configFile = lib.mapAttrs mkOutOfStoreSymlink dots;
}

