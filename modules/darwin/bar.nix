# macOS visual/status-bar adornments.
#
# - `services.sketchybar`  — SketchyBar replaces the system menu bar with a
#   scriptable version. launchd agent here just plumbs logs to /tmp for
#   debugging; the bar configuration itself is in the sketchybar dotfiles.
# - `services.jankyborders` — highlights the focused window with a colored
#   border. Auto-disabled when the active window manager is `omniwm`, which
#   ships its own borders (configured via `[borders]` in settings.toml).
#
# Split out of the old `darwin/home-manager.nix` because they're system
# services, not home-manager config.
{ config, ... }:

let
  inherit (config.myOptions.windowManager) backend;
in
{
  services = {
    sketchybar = {
      enable = true;
    };

    # https://mynixos.com/options/services.jankyborders
    # active_color / inactive_color come from stylix.targets.jankyborders
    # (system-level Stylix darwinModule).
    jankyborders = {
      enable = backend != "omniwm";
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
