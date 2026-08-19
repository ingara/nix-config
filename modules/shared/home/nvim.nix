# Neovim — the LazyVim config tree (live-edited dotfile symlink).
#
# Per-file symlinks (not whole-dir): nvim-theme.nix generates
# ~/.config/nvim/lua/theme.lua as its own xdg.configFile entry, so the config
# dir must stay a real dir for the generated sidecar to coexist. defaultSkip
# drops the repo cruft (LICENSE/README/stylua.toml) that lives in the source.
#
# The binary stays in shared/packages.nix, NOT here: darwin needs nvim at
# system scope (paired with the system-level EDITOR=nvim; user scope would
# break sudoedit), and an HM module can only add to home.packages.
{
  config,
  lib,
  ...
}:
let
  dots = import ./lib/dotfiles.nix { inherit lib; };
in
{
  xdg.configFile = dots.mkPerFileDots {
    inherit config;
    srcRel = "nvim";
    xdgRel = "nvim";
  };
}
