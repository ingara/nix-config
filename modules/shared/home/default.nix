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
    # Definition order affects generated package/completion lists; keep the
    # direct import until the aggregate owns this position without moving drvs.
    ./cli-ux.nix
    ./developer-environment.nix
    ./fish.nix
    ./zsh.nix
    ./git.nix
    ./gh-dash.nix
    ./ghostty.nix
    ./wezterm.nix
    ./theme.nix
    ./sketchybar.nix
  ];

  # Adopt XDG base dirs on every HM host: exports XDG_*_HOME to shells (and the
  # systemd user env on Linux) and lets xdg.enable-gating modules (e.g. paneru)
  # default their configs under ~/.config.
  xdg.enable = true;

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
        assertion = pkgs.stdenv.hostPlatform.isDarwin || lib.all (w: lib.elem w linuxWms) wm.enabled;
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
