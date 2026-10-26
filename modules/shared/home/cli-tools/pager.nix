{ lib, pkgs, ... }:

let
  sessionVariables = {
    PAGER = "less";
    LESS = "-R --quit-if-one-screen --no-init";
  };
in
{
  home = { inherit sessionVariables; };
  systemd.user.sessionVariables = lib.mkIf pkgs.stdenv.hostPlatform.isLinux sessionVariables;
  myOptions.developerEnvironmentParity.surfaces.cliPager = { inherit sessionVariables; };
}
