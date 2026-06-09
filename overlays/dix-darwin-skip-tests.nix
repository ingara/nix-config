# dix — disable the test phase on darwin.
#
# dix 2.0.0 (nixpkgs, 2026-06-04) ships unit tests that hardcode a path
# validator accepting only `/nix/store` or `/tmp/` prefixes. The package sets
# `env.TMPDIR = "/tmp/"` and `--skip`s four tests to make this work, but the
# mitigation is incomplete on macOS: the Rust test harness canonicalizes
# `/tmp/` through the `/private/tmp` symlink, so the created temp paths start
# with `/private/tmp` and ~11 tests panic — even though `aarch64-darwin` is in
# `meta.platforms`. The binary itself builds fine; only the check phase fails.
#
# No `TMPDIR` value can fix it (the prefix list is hardcoded in the test), so
# we skip the whole check phase on darwin. The same package still runs its full
# test suite on the Linux servers. Remove once upstream fixes 2.0.x on darwin.
_final: prev:

prev.lib.optionalAttrs prev.stdenv.isDarwin {
  dix = prev.dix.overrideAttrs { doCheck = false; };
}
