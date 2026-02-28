{ pkgs }:

with pkgs;
[
  bat
  bottom
  eza
  fastfetch
  fd
  gh
  git
  jq
  just
  lazygit
  neovim
  ripgrep
  tealdeer
  zellij

  # desktop theming
  (catppuccin-kde.override {
    flavour = [ "macchiato" ];
    accents = [ "mauve" ];
    winDecStyles = [ "modern" ];
  })
  papirus-icon-theme

  # KDE widgets
  application-title-bar

  # fonts
  maple-mono.NF
]
