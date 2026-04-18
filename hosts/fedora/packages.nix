{ pkgs }:

with pkgs;
let
  shared-packages = import ../../modules/shared/packages.nix { inherit pkgs; };
in
shared-packages
++ [
  docker
  # KDE theming
  (catppuccin-kde.override {
    flavour = [ "macchiato" ];
    accents = [ "mauve" ];

  })
  papirus-icon-theme

]
