# Flake-parts module: maps easy-hosts tags to module bundles (the role
# aggregator). Auto-imported by `import-tree ./flake-modules` in the public
# flake (no "/_" in the path), and re-exported to downstream consumers via
# flakeModules.default (see flake-module.nix) so their tagged hosts receive
# these bundles.
#
# Public, nixos-only tags. Downstream perTag contributors add a SECOND
# easy-hosts.perTag contributor; the two merge (every contributor's
# function is called for a given tag and their `modules` lists concatenated —
# the same merge the `headless` tag already relies on).
_:
let
  mkRole = import ./_lib.nix;
  bundles = {
    graphical = mkRole {
      system = [ ../../modules/nixos/graphical.nix ];
      home = [
        ../../modules/linux/wm-common.nix
        ../../modules/linux/hyprland.nix
        ../../modules/linux/niri.nix
      ];
    };
    gaming = mkRole {
      system = [ ../../modules/nixos/gaming.nix ];
      home = [ ../../modules/linux/mangohud.nix ];
    };
    nvidia = mkRole {
      system = [ ../../modules/nixos/nvidia.nix ];
    };
  };
in
{
  easy-hosts.perTag = tag: bundles.${tag} or { modules = [ ]; };
}
