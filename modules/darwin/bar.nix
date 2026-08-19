# macOS visual/status-bar adornments.
#
# - `services.sketchybar`  — SketchyBar replaces the system menu bar with a
#   scriptable version. launchd agent here just plumbs logs to /tmp for
#   debugging; the bar configuration itself is in the sketchybar dotfiles.
# - `services.jankyborders` — highlights the focused window with a colored
#   border. Auto-disabled when the active window manager is `omniwm` (which
#   ships its own borders), `paneru` (optional native border under
#   [decorations.active.border]), or `nehir` (native focus borders).
{ config, lib, ... }:

let
  cfg = config.myOptions.windowManager;
in
{
  services = {
    sketchybar = {
      enable = true;
    };

    # https://mynixos.com/options/services.jankyborders
    # active_color / inactive_color come from stylix.targets.jankyborders
    # (system-level Stylix darwinModule). Disabled whenever a native-border WM is
    # installed — jankyborders plus a native border renders double borders.
    jankyborders = {
      enable =
        !(lib.elem "omniwm" cfg.enabled || lib.elem "paneru" cfg.enabled || lib.elem "nehir" cfg.enabled);
      style = "round";
      width = 3.0;
      hidpi = true;
      order = "above";
    };
  };

  launchd.user.agents = {
    sketchybar.serviceConfig = {
      StandardOutPath = "/tmp/sketchybar.log";
      StandardErrorPath = "/tmp/sketchybar.log";
    };
  };
}
