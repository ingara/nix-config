# skhd.zig manages its own launchd agents via `skhd --install-service`:
#   - User agent (com.jackielii.skhd) via SMAppService
#   - skhd-grabber root daemon (for .remap tap-hold rules)
#   - Karabiner VHIDD daemon (DriverKit virtual keyboard)
#
# One-time setup: `skhd --install-service` (interactive — handles sudo,
# TCC prompts, grabber + dext installation).
#
# Config files + entrypoint: written here (this module owns skhd's whole
# concern). Homebrew cask: homebrew.nix.
{ lib, ... }:
let
  dots = import ../shared/home/lib/dotfiles.nix { inherit lib; };
in
{
  home-manager.sharedModules = [
    (
      { config, lib, ... }:
      let
        wm = config.myOptions.windowManager;
        # This sharedModule only exists on darwin (skhd is macOS-only), so the
        # isDarwin guard the central dotfiles.nix used is implicit here.
        anyWM = wm.enabled != [ ];
        omniwm = lib.elem "omniwm" wm.enabled;
        src = relPath: dots.mkSource { inherit config relPath; };
      in
      {
        # `skhd --restart-service` (SMAppService) fails with SpawnFailed in
        # the activation context — kickstart the agent via launchd instead.
        home.activation.restartSkhd = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          /bin/launchctl kickstart -k "gui/$(id -u)/com.jackielii.skhd" || true
        '';

        xdg.configFile =
          lib.optionalAttrs anyWM {
            "skhd/common.skhd".source = src "skhd/common.skhd";
            "skhd/builtin-keyboard.skhd".source = src "skhd/builtin-keyboard.skhd";
            "skhd/skhdrc".text =
              lib.concatStringsSep "\n" (
                [
                  ''.load "builtin-keyboard.skhd"''
                  ''.load "common.skhd"''
                ]
                ++ lib.optional omniwm ''.load "omniwm.skhd"''
              )
              + "\n";
          }
          // lib.optionalAttrs omniwm {
            "skhd/omniwm.skhd".source = src "skhd/omniwm.skhd";
          };
      }
    )
  ];
}
