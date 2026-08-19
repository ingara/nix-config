# CLI productivity tools cluster — one tool per file, imported as a unit by
# `home/default.nix`.
_: {
  imports = [
    ./bat.nix
    ./direnv.nix
    ./fzf.nix
    ./mise.nix
    ./ripgrep.nix
    ./worktrunk.nix
    ./zoxide.nix
  ];
}
