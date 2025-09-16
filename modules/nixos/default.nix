{ config, lib, pkgs, userConfig, ... }:

{
  imports = [
    ./1password.nix
    # Add other nixos-specific modules here as needed
  ];
}