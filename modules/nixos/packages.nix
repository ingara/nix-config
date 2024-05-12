{ pkgs }:

with pkgs;
let
  shared-packages = import ../shared/packages.nix { inherit pkgs; };
in
shared-packages ++ [
  _1password-gui
  fastfetch
  neofetch
  nerdfetch
  rofi
  xclip
  firefox
]
