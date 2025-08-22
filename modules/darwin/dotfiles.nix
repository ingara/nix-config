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
  # home.file."Library/Application Support/" = lib.mapAttrs symlink appsupport;
  # home.file."Library/Application Support/Cursor/User/keybindings.json" = config.lib.file.mkOutOfStoreSymlink "${configPath}/dotfiles/cursor/keybindings.json";
  home.file."Library/Application Support/Cursor/User/keybindings.json".source = ../../dotfiles/cursor/keybindings.json;
}


