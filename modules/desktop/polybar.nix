{ pkgs, ... }:
{
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
          compositing = {
            background = "source";
            foreground = "over";
            overline = "over";
            underline = "over";
            border = "over";
          };
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
          modules.left = [
            "launcher"
            "workspaces"
          ];
          modules.right = [
            "memory"
            "cpu"
            "sysmenu"
          ];
          wm.name = "bspwm";
          wm.restack = "bspwm";
          enable.ipc = true;
        };
      };
    };
  };
}
