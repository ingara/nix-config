# Credential-free developer environment shared by personal and agent identities.
{ lib, pkgs, ... }:

let
  developerPackages = import ./developer-packages.nix { inherit lib pkgs; };
in
{
  imports = [
    ./cli-tools
    ./ai/mcp.nix
    ./ai/opencode.nix
    ./cli-ux.nix
    ./gh-dash.nix
    ./git-ux.nix
    ./nvim.nix
    ./tmux.nix
  ];

  home.packages = developerPackages.packages;

  programs = {
    fish.shellAliases = {
      c = "claude";
      oc = "opencode";
    };
    zsh.shellAliases = {
      c = "claude";
      oc = "opencode";
    };
  };

  myOptions.developerEnvironmentParity = {
    packages = developerPackages.capabilities;
    aliases = {
      c = "claude";
      oc = "opencode";
    };
  };
}
