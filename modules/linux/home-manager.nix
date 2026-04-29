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
    ../shared/home/dotfiles.nix
    ../shared/home
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
