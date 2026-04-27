_final: prev:

# Workaround: skip mise's checkPhase on darwin.
#
# Around the 2026-04-18 darwin SDK migration (NixOS/nixpkgs#508474),
# Hydra's aarch64-darwin queue stopped publishing builds for `mise` —
# the package is missing from "latest evaluation" of the
# nixos:unstable jobset, leaving cache.nixos.org without prebuilt
# outputs for any nixos-unstable commit since. Locally building falls
# back to running mise's full `cargo test --all-features` suite with
# `dontUseCargoParallelTests = true`, which takes ~24 minutes and is
# unnecessary for downstream consumption — we're using mise as a
# tool, not validating upstream tests.
#
# Disabling checks reduces the rebuild from ~24 minutes to a couple
# minutes of pure compile.
#
# REMOVE WHEN: Hydra is publishing mise.aarch64-darwin builds again
# and cache.nixos.org has them for our locked nixpkgs rev. Verify:
#   nix path-info nixpkgs#mise --store https://cache.nixos.org
# Should return a store path (not a 404). Also worth checking:
#   https://hydra.nixos.org/job/nixos/unstable/nixpkgs.mise.aarch64-darwin
# When the page lists recent successful builds again, the override is
# probably no longer pulling its weight.
{
  mise = prev.mise.overrideAttrs (
    _old:
    prev.lib.optionalAttrs prev.stdenv.isDarwin {
      doCheck = false;
    }
  );
}
