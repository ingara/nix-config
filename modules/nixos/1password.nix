{ config, lib, pkgs, userConfig, ... }:

{
  # Allow 1Password unfree packages
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "1password-gui"
    "1password"
  ];

  # Enable polkit for 1Password authentication
  security.polkit.enable = true;

  # Enable 1Password CLI
  programs._1password.enable = true;
  
  # Enable 1Password GUI (Linux only - macOS uses Homebrew)
  programs._1password-gui = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
    polkitPolicyOwners = [ userConfig.username ];
  };
}