# Aliases whose commands are owned by the portable CLI UX capability contract.
{ pkgs }:

(import ./cli-ux-capabilities.nix { inherit pkgs; }).aliases
