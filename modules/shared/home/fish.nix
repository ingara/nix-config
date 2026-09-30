# Compatibility aggregator for the personal Fish session.
{
  imports = [
    ./fish-session-personal.nix
  ];

  programs.fish.shellAliases = import ./aliases.nix { };
}
