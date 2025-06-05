{ configPath }: { config, lib, ... }:

let
  appsupport = {
    "Cursor/User/keybindings.json" = "cursor/keybindings.json";
  };

  symlink = key: value: {
    source = config.lib.file.mkOutOfStoreSymlink "${configPath}/dotfiles/${value}";
  };
in
{
  home.file."Library/Application Support" = lib.mapAttrs symlink appsupport;
}


