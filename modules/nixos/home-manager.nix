{ config, pkgs, lib, ... }:
let
  user = "ingar";
in
{
  imports = [
    (import ../shared/dotfiles.nix { configPath = "${config.home.homeDirectory}/nix-config"; })
  ];
  home = {
    enableNixpkgsReleaseCheck = false;
    username = "${user}";
    homeDirectory = "/home/${user}";
    packages = pkgs.callPackage ./packages.nix {};
    file = { };
    stateVersion = "23.11";
  };
  programs = import ../shared/home-manager.nix { inherit config pkgs lib; };
  gtk = {
    enable = true;
  };
  services = {
    polybar = {
      enable = true;
      package = pkgs.polybarFull;
      script = "polybar main &";
      settings = {
        "global/wm" = {
          margin.bottom = 0;
          margin.top = 0;
        };
        "settings" = {
          screenchange.reload = false;
          compositing.background = "source";
          compositing.foreground = "over";
          compositing.overline = "over";
          compositing.underline = "over";
          compositing.border = "over";
          pseudo.transparency = false;
        };
        "bar/main" = {
          monitor.strict = false;
          bottom = false;
          fixed.center = true;
          width = "98%";
          height = 40;
          radius.top = 2.0;
          radius.bottom = 2.0;
          modules.left = [ "launcher" "workspaces" ];
          modules.right = [ "memory" "cpu" "sysmenu" ];
          wm.name = "bspwm";
          wm.restack = "bspwm";
          enable.ipc = true;
        };
      };
    };
  };
}
