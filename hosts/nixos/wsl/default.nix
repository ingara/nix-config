{
  lib,
  pkgs,
  userConfig,
  ...
}:

let
  user = userConfig.username;
in
{
  imports = [
    ../base.nix
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  networking.useDHCP = lib.mkDefault true;
  system.stateVersion = "23.11";

  networking.hostName = "nixos-wsl";

  wsl = {
    enable = true;
    defaultUser = user;
    startMenuLaunchers = true;

    # WSL-specific settings
    wslConf = {
      automount.root = "/mnt";
      interop.appendWindowsPath = false;
      network.generateHosts = false;
    };
  };

  # WSL specific packages
  environment.systemPackages = with pkgs; [
    wget
    curl
  ];
}
