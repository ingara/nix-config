# Zellij — the hand-tuned keybind config (live-edited dotfile symlink).
#
# Kept as a symlink (not programs.zellij) deliberately: config.kdl is ~600 lines
# of frequently hand-edited keybinds, and programs.zellij.settings would mean a
# fragile KDL→Nix→KDL round-trip (multi-action binds, shared_except groups,
# plugin blocks) plus losing live-edit — same call as nvim.
#
# Per-file symlinks (not whole-dir): terminal-themes.nix generates the sidecars
# (themes/stylix.kdl, layouts/zjstatus.kdl, session-colors.sh) into this config
# dir, so it must stay a real dir for them to coexist. The source dir holds only
# config.kdl, so nothing extra to exclude.
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
    srcRel = "zellij";
    xdgRel = "zellij";
  };
}
