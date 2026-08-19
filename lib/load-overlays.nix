# Load every overlay in `dir` into a `[overlay]` list — each top-level
# `*.nix` file plus each subdirectory holding a `default.nix`.
#
# A value-producing helper (not a flake-module — `public/lib/` isn't swept by
# import-tree), called by `modules/shared/nixpkgs.nix` to populate
# `nixpkgs.overlays` for system and Home Manager modules.
dir:
with builtins;
map (n: import (dir + ("/" + n))) (
  filter (n: match ".*\\.nix" n != null || pathExists (dir + ("/" + n + "/default.nix"))) (
    attrNames (readDir dir)
  )
)
