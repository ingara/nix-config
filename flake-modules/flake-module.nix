# Export `flake.flakeModules.default` so the private root flake can import
# the reusable presets (easy-hosts shared/perClass/perTag bundles +
# flake.lib.devShellBase) without pulling in
# public-specific host declarations or perSystem outputs.
#
# Not exported in flakeModules.default:
#   - ./per-system.nix (each flake builds its own devShells/formatter/checks)
#   - ./hosts.nix      (public's placeholder hosts; private declares real ones)
_: {
  flake.flakeModules.default = {
    imports = [
      ./easy-hosts-presets.nix
      ./lib.nix
      # The role aggregator (graphical/gaming/nvidia perTag bundles). The public
      # flake picks this up via import-tree for its own outputs; downstream
      # private flakes only see it through this explicit re-export, so a tagged
      # private host gets the bundles iff it's listed here.
      ./roles/default.nix
    ];
  };
}
