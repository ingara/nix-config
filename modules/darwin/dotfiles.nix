{ configPath }:
{ config, lib, ... }:

{
  # For some reason, out of store symlinks are not working when linking to ~/Library/Application Support/
  home.file."Library/Application Support/Cursor/User/keybindings.json".source =
    ../../dotfiles/cursor/keybindings.json;
}
