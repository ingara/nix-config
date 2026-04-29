# Export `flake.flakeModules.default` so the private root flake can import
# the reusable presets (easy-hosts shared/perClass/perTag bundles + the
# mkFedoraHome helper + flake.lib.devShellBase) without pulling in
# public-specific host declarations or perSystem outputs.
#
# The `options.flake.lib` declaration lives in `./lib.nix` rather than
# here because it needs to be visible to downstream flakes that import
# flakeModules.default (this file itself is NOT in that import list).
#
# Not exported in flakeModules.default:
#   - ./per-system.nix (each flake builds its own devShells/formatter/checks)
#   - ./hosts.nix      (public's placeholder hosts; private declares real ones)
_: {
  flake.flakeModules.default = {
    imports = [
      ./easy-hosts-presets.nix
      ./home-configs.nix
      ./lib.nix
    ];
  };
}
