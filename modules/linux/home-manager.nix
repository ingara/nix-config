{
  config,
  pkgs,
  ...
}:
let
  user = config.myOptions.user.username;
in
{
  imports = [
    ../shared/dotfiles.nix
    ../shared/home-manager.nix
  ];

  home = {
    enableNixpkgsReleaseCheck = false;
    username = "${user}";
    homeDirectory = "/home/${user}";
    packages = import ../shared/packages.nix { inherit pkgs; };
    file = { };
    stateVersion = "23.11";
  };
}
