# Neovim — the LazyVim config tree (live-edited dotfile symlink).
#
# Per-file symlinks (not whole-dir): nvim-theme.nix generates
# ~/.config/nvim/lua/theme.lua as its own xdg.configFile entry, so the config
# dir must stay a real dir for the generated sidecar to coexist. defaultSkip
# drops the repo cruft (LICENSE/README/stylua.toml) that lives in the source.
#
{
  config,
  lib,
  pkgs,
  ...
}:
let
  dots = import ./lib/dotfiles.nix { inherit lib; };
in
{
  imports = [ ./nvim-theme.nix ];

  # Nvim-treesitter builds parsers locally and Mason installs language tools;
  # Darwin already supplies the required compiler through Xcode CLT.
  home.packages = [
    pkgs.neovim
    pkgs.curl
    pkgs.gzip
    pkgs.gnutar
    pkgs.nixd
    pkgs.tree-sitter
    pkgs.unzip
  ]
  ++ lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.stdenv.cc;

  xdg.configFile = dots.mkPerFileDots {
    inherit config;
    srcRel = "nvim";
    xdgRel = "nvim";
  };

  myOptions.developerEnvironmentParity = {
    packages = {
      nvim = {
        package = pkgs.neovim;
        commands = [ "nvim" ];
      };
      nvimCurl = {
        package = pkgs.curl;
        commands = [ "curl" ];
      };
      nvimGzip = {
        package = pkgs.gzip;
        commands = [ "gzip" ];
      };
      nvimTar = {
        package = pkgs.gnutar;
        commands = [ "tar" ];
      };
      nvimNixd = {
        package = pkgs.nixd;
        commands = [ "nixd" ];
      };
      nvimTreeSitter = {
        package = pkgs.tree-sitter;
        commands = [ "tree-sitter" ];
      };
      nvimUnzip = {
        package = pkgs.unzip;
        commands = [ "unzip" ];
      };
    }
    // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      nvimCompiler = {
        package = pkgs.stdenv.cc;
        commands = [ "cc" ];
      };
    };
  };
}
