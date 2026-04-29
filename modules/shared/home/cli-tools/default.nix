# CLI productivity tools cluster.
#
# Each tool is a one-file module. Keeping them under a `cli-tools/`
# subdirectory rather than flat at `home/` matches the bundle-growth
# trajectory (previously a single `cli-tools.nix` with 6 programs) and
# lets the aggregator import the whole cluster in one line from
# `home/default.nix`.
_: {
  imports = [
    ./bat.nix
    ./direnv.nix
    ./fzf.nix
    ./mise.nix
    ./ripgrep.nix
    ./zoxide.nix
  ];
}
