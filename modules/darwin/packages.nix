{ pkgs }:

with pkgs;
let
  shared-packages = import ../shared/packages.nix { inherit pkgs; };
in
shared-packages
++ [
  colima
  terminal-notifier

  # Better userland for macOS
  coreutils
  findutils
  gnugrep
  gnused

  dockutil
  pkgs.nerd-fonts.hack
  pkgs.nerd-fonts.caskaydia-cove
  pkgs.nerd-fonts.zed-mono
  pkgs.nerd-fonts.victor-mono
  pkgs.sketchybar-app-font
]
