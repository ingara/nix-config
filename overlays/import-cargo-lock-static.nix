# TEMPORARY: route `rustPlatform.importCargoLock` (and therefore
# `buildRustPackage { cargoLock.lockFile = ...; }`) through
# `static.crates.io` instead of `crates.io/api/v1/crates`.
#
# crates.io's WAF rejects bare `curl/<version>` User-Agent strings —
# the default that nixpkgs's `fetchurl` (and therefore `importCargoLock`'s
# per-crate fetch) sends — with HTTP 403. The `static.crates.io` CDN
# endpoint serves the same tarballs without that restriction.
#
# Symptom this fixes: out-of-tree Rust packages that aren't in nixpkgs
# (so their crate FODs aren't on cache.nixos.org via Hydra) fail to
# build with `curl: (22) The requested URL returned error: 403` on
# hosts that don't already have the crate tarballs in /nix/store.
# `tmux-agent-sidebar-bin` in
# `public/modules/shared/home/tmux.nix` is the immediate trigger.
#
# Upstream fix: nixpkgs PR #524985, merged into master on 2026-05-27.
# Our flake.lock pin is nixos-unstable @ 2026-05-23 and that channel
# branch hasn't moved past the merge yet. Remove this overlay once
# `git log --oneline -- pkgs/build-support/rust/import-cargo-lock.nix`
# inside `$(nix eval --raw nixpkgs#path)` shows commit c0a89c37 (or
# any nixos-unstable rev dated after 2026-05-27).
#
# FOD subtlety: FOD .drv paths are addressed by (name, outputHash) only —
# the URL is metadata that doesn't affect the path. That means this overlay
# produces a .drv with the SAME path as the un-overlaid version; if a host
# already has the old (crates.io-URL) .drv on disk from a previous failed
# eval, Nix reuses the on-disk file instead of rewriting it with the new
# URL, and the fetch keeps 403-ing against crates.io's WAF.
#
# Workaround for hosts in that state (one-off): `nix-store --delete
# --ignore-liveness` the relevant `crate-*.tar.gz.drv` paths (and any
# `*.lock` left behind by the interrupted fetch). Once deleted, the next
# eval writes a fresh .drv at the same path with the static.crates.io URL,
# and the fetch succeeds.
#
# We deliberately do NOT rename the FOD (e.g. with a `-static` suffix) to
# force a new path: that would invalidate the input-addressing of every
# downstream per-crate unpack drv (`<name>-<version>.drv`), cascading
# hundreds of rebuilds across every Rust package in the closure that has
# nothing to do with the actual fetch problem.
#
# `rustPlatform` is a scope (built via `makeScopeWithSplicing'`), and
# `buildRustPackage` resolves `importCargoLock` through the scope's
# `callPackage`. A naive `prev.rustPlatform // { importCargoLock = ...; }`
# only updates the outer view — `buildRustPackage` still captures the
# original. `overrideScope` rewrites the scope itself, so the swapped
# `importCargoLock` reaches `cargoLock`-using callers too.
_final: prev: {
  rustPlatform = prev.rustPlatform.overrideScope (
    rfinal: _rprev:
    let
      # Patch at eval time with builtins.replaceStrings rather than a
      # runCommand derivation, so the substitution doesn't require the
      # target system's stdenv (which would force IFD across the
      # darwin → aarch64-linux build boundary).
      original = builtins.readFile (prev.path + "/pkgs/build-support/rust/import-cargo-lock.nix");
      patched =
        builtins.replaceStrings [ "https://crates.io/api/v1/crates" ] [ "https://static.crates.io/crates" ]
          original;
      patchedSource = builtins.toFile "import-cargo-lock.nix" patched;
    in
    {
      importCargoLock = rfinal.callPackage patchedSource { };
    }
  );
}
