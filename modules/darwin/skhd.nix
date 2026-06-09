# skhd.zig manages its own launchd agents via `skhd --install-service`:
#   - User agent (com.jackielii.skhd) via SMAppService
#   - skhd-grabber root daemon (for .remap tap-hold rules)
#   - Karabiner VHIDD daemon (DriverKit virtual keyboard)
#
# One-time setup: `skhd --install-service` (interactive — handles sudo,
# TCC prompts, grabber + dext installation).
#
# Config files: dotfiles.nix (mkOutOfStoreSymlink).
# Homebrew cask: homebrew.nix.
_: {
  home-manager.sharedModules = [
    (
      { lib, ... }:
      {
        home.activation.restartSkhd = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          /opt/homebrew/bin/skhd --restart-service >/dev/null 2>&1 || true
        '';
      }
    )
  ];
}
