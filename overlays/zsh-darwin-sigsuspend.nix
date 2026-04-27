_final: prev:

# Workaround for upstream nixpkgs zsh build regression on darwin.
#
# After PR NixOS/nixpkgs#508474 (darwin SDK migration), zsh's autoconf
# `AC_RUN_IFELSE` probe for sigsuspend() fails inside the build sandbox,
# so zsh is compiled with the racy pause()-based fallback. That fallback
# loses SIGCHLD wakeups when reaping `$(...)` subshells, which deadlocks
# any interactive zsh that runs hooks doing command substitution
# (starship init, direnv hook, iTerm2 shell-integration, etc.). The same
# deadlock is what hangs `direnv`'s checkPhase on aarch64-darwin.
#
# Forcing `zsh_cv_sys_sigsuspend=yes` skips the broken probe and compiles
# zsh with the correct sigsuspend() path. The runtime answer on darwin is
# always yes; the probe only fails because of a sandbox-vs-real-kernel
# discrepancy introduced by the SDK migration.
#
# Tracking:
#   - https://github.com/NixOS/nixpkgs/issues/513543 (root cause, zsh)
#   - https://github.com/NixOS/nixpkgs/issues/513019 (direnv hang, unstable)
#   - https://github.com/NixOS/nixpkgs/issues/507531 (direnv hang, 25.11)
#
# REMOVE WHEN: #513543 is closed and the fix is in our pinned nixpkgs.
# Verify with:
#   nix log $(nix-build '<nixpkgs>' -A zsh --no-out-link) \
#     | grep 'POSIX sigsuspend'
# Expect "yes". Also: `nm -u $(command -v zsh) | grep -E '_(sigsuspend|pause)$'`
# should print `_sigsuspend`, not `_pause`.
{
  zsh = prev.zsh.overrideAttrs (
    old:
    prev.lib.optionalAttrs prev.stdenv.isDarwin {
      preConfigure = (old.preConfigure or "") + ''
        export zsh_cv_sys_sigsuspend=yes
      '';
    }
  );
}
