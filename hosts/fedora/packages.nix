{ pkgs }:

with pkgs;
let
  shared-packages = import ../../modules/shared/packages.nix { inherit pkgs; };
in
shared-packages
++ [
  docker
  # KDE icon theme — Plasma colorscheme + cursors come from stylix.
  papirus-icon-theme
]
