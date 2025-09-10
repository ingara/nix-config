{
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
