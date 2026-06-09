# Linux desktop (X11 / minimal WM) concern. Opt-in per host — only
# `vboxnixos` imports this at time of writing (fedora uses Plasma via
# `public/hosts/fedora` and ships a different desktop surface).
{ pkgs, ... }:
{
  imports = [
    ./gtk.nix
    ./polybar.nix
  ];

  home.packages = with pkgs; [
    firefox
    rofi
    xclip
  ];
}
