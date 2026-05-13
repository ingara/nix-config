# Home-manager aggregator for cross-platform concerns.
#
# Imported by each platform's HM wrapper (`public/modules/darwin/default.nix`
# for darwin, `public/modules/linux/home-manager.nix` for linux/fedora).
# Each file under this directory handles one program or one small family
# (see `cli-tools.nix` for the bundle policy).
#
# Import order notes: the sequence below was chosen during the monolith
# split to match the `programs.*` declaration order in the original
# `home-manager.nix`, so HM's `home.packages` list kept the same element
# sequence and the resulting wrapper derivations could be diffed against
# the pre-refactor baseline. After that one-time verification, feel free
# to resort — the order no longer carries meaning beyond convention.
_:

{
  imports = [
    ./cli-tools
    ./fish.nix
    ./zsh.nix
    ./starship.nix
    ./git.nix
    ./wezterm.nix
    ./tmux.nix
    ./theme.nix
    ./nvim-theme.nix
    ./sketchybar.nix
  ];
}
