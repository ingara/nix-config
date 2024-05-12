{ configPath }: { config, lib, ... }:

let
  dots = {
    # "targetfile" = "testrc";
    # "ideavim/ideavimrc" = ".ideavimrc";
    # "yabai/yabairc" = "yabairc";
    # "skhd/skhdrc" = "skhdrc";
    "lazygit/config.yml" = "lazygit.yml";
    "nvim" = "nvim";
    "alacritty" = "alacritty";
  };

mkOutOfStoreSymlink = key: value: {
  source = config.lib.file.mkOutOfStoreSymlink "${configPath}/modules/shared/configs/${value}";
};
in
{
  xdg.configFile = lib.mapAttrs mkOutOfStoreSymlink dots;
}

