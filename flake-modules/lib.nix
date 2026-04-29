# Flake-level lib helpers exported to downstream consumers (the private
# root flake imports these via publicFlake.flakeModules.default; public's
# own flake also picks this file up via import-tree so `lib` is available
# inside public-side perSystem too).
#
# Also declares `options.flake.lib` so multiple flake-modules can each set
# `flake.lib.<name>` and have them merged — flake-parts' base schema has
# no declaration for `flake.lib`. This declaration needs to live in a
# file that's included in flakeModules.default (i.e. this file or its
# siblings in that list) so downstream flakes see it too.
{ lib, ... }:
{
  options.flake.lib = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = { };
    description = "Reusable flake-level helpers (mkFedoraHome, devShellBase, …).";
  };

  config.flake.lib.devShellBase = pkgs: [
    pkgs.nixfmt
    pkgs.statix
    pkgs.just
    pkgs.git
    pkgs.bash
    pkgs.lefthook
  ];
}
