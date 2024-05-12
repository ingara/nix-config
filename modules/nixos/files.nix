{ user, ... }:
let
  home = builtins.getEnv "HOME";
  xdg_configHome = "${home}/.config";
in
{
}
