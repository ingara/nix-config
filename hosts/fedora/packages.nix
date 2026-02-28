{ pkgs }:

with pkgs;
let
  shared-packages = import ../../modules/shared/packages.nix { inherit pkgs; };
in
shared-packages
++ [
  # KDE theming
  (catppuccin-kde.override {
    flavour = [ "macchiato" ];
    accents = [ "mauve" ];
    winDecStyles = [ "modern" ];
  })
  papirus-icon-theme

  # KDE widgets
  application-title-bar
]
