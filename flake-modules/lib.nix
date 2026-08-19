# Flake-level lib helpers exported through `flakeModules.default`. The private
# root imports that module, while the public flake imports this file through
# `import-tree` for its own per-system outputs.
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
    description = "Reusable flake-level helpers.";
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
