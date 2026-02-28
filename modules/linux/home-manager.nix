{
  config,
  pkgs,
  lib,
  userConfig,
  hasGui ? true,
  sshSignProgram ? null,
  ...
}:
let
  user = userConfig.username;
in
{
  imports = [
    (import ../shared/dotfiles.nix {
      configPath = "${config.home.homeDirectory}/nix-config";
      wmBackend = "none";
    })
  ];
  home = {
    enableNixpkgsReleaseCheck = false;
    username = "${user}";
    homeDirectory = "/home/${user}";
    packages = import ../shared/packages.nix { inherit pkgs; };
    file = { };
    stateVersion = "23.11";
  };
  programs = import ../shared/home-manager.nix {
    inherit
      config
      pkgs
      lib
      userConfig
      hasGui
      sshSignProgram
      ;
    gitCredentialHelper = "store";
  };
}
