# Home-manager aggregator for cross-platform concerns.
#
# Imported by each platform's HM wrapper (`public/modules/darwin/default.nix`
# for darwin, `public/modules/linux/home-manager.nix` for Linux).
# Each file under this directory handles one program or one small family
# (see `cli-tools/default.nix` for the bundle policy).
{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./cli-tools
    ./ai
    ./fish.nix
    ./zsh.nix
    ./starship.nix
    ./git.nix
    ./nvim.nix
    ./ghostty.nix
    ./zellij.nix
    ./wezterm.nix
    ./tmux.nix
    ./theme.nix
    ./nvim-theme.nix
    ./sketchybar.nix
    ./showy-quota.nix
    ./terminal-themes.nix
  ];

  # Adopt XDG base dirs on every HM host: exports XDG_*_HOME to shells (and the
  # systemd user env on Linux) and lets xdg.enable-gating modules (e.g. paneru)
  # default their configs under ~/.config.
  xdg.enable = true;

  home.sessionVariables = {
    PAGER = "less";
    LESS = "-R --quit-if-one-screen --no-init";
  };
  # sessionPath reaches bash/zsh/fish alike — the one place go/bin joins PATH.
  home.sessionPath = [
    "$HOME/go/bin"
  ];

  # Cross-platform windowManager invariants. Shared HM scope so they run on
  # Linux too — darwin/window-manager.nix is darwin-only and can't guard a
  # Linux host.
  assertions =
    let
      wm = config.myOptions.windowManager;
      linuxWms = (import ../_wm-names.nix).linux;
    in
    [
      {
        assertion = pkgs.stdenv.isDarwin || lib.all (w: lib.elem w linuxWms) wm.enabled;
        message = ''
          myOptions.windowManager.enabled contains a darwin-only WM on a Linux
          host (Linux WMs: ${toString linuxWms}). macOS WM dotfile bundles must
          not be activated on Linux.
        '';
      }
      {
        assertion = wm.default == "none" || lib.elem wm.default wm.enabled;
        message = ''
          myOptions.windowManager.default = "${wm.default}" is not in enabled
          (${toString wm.enabled}). Add it to `enabled` or set default = "none".
        '';
      }
    ];
}
