# Standalone home-manager configurations.
#
# easy-hosts doesn't model home-manager as a host class — it only builds
# nixosConfigurations / darwinConfigurations. Fedora (and other standalone
# HM) hosts use `home-manager.lib.homeManagerConfiguration` directly; this
# file exposes `flake.lib.mkFedoraHome` so downstream flakes can build
# their own standalone HM configurations with identity injected.
#
# No placeholder `flake.homeConfigurations.*` is declared here: having a
# public placeholder plus a downstream override forces flake-parts'
# module system to evaluate both, and on darwin the catppuccin starship
# module triggers IFD on an x86_64-linux derivation that can't be built
# without a remote builder. Keeping the set empty here avoids that.
{ inputs, ... }:
let
  # Same overlay-loading logic as public/modules/shared/nixpkgs.nix; replicated
  # here because standalone home-manager constructs pkgs at the call site
  # (HM ignores `nixpkgs.overlays` from modules when `pkgs` is pre-supplied).
  overlaysDir = ../overlays;
  overlays =
    with builtins;
    map (n: import (overlaysDir + ("/" + n))) (
      filter (n: match ".*\\.nix" n != null || pathExists (overlaysDir + ("/" + n + "/default.nix"))) (
        attrNames (readDir overlaysDir)
      )
    );

  mkFedoraHome =
    {
      extraModules ? [ ],
    }:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = import inputs.nixpkgs {
        system = "x86_64-linux";
        inherit overlays;
        config = {
          allowUnfree = true;
          allowInsecure = false;
        };
      };
      extraSpecialArgs = {
        inherit inputs;
      };
      modules = [
        ../modules/shared/options.nix
        {
          myOptions.hasGui = true;
          myOptions.dotfiles.repoRoot = inputs.nixpkgs.lib.mkDefault "/home/user/nix-config";
        }
        ../hosts/fedora
      ]
      ++ extraModules;
    };
in
{
  flake.lib.mkFedoraHome = mkFedoraHome;
}
