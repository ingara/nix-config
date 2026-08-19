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
    ../shared/home
  ];

  home = {
    enableNixpkgsReleaseCheck = false;
    username = "${user}";
    homeDirectory = "/home/${user}";
    packages = import ../shared/packages.nix { inherit pkgs; };
    stateVersion = "23.11";
  };
}
