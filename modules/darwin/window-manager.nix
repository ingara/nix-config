{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.myOptions.windowManager;
in
{
  options.myOptions.windowManager = {
    backend = lib.mkOption {
      type = lib.types.enum [
        "yabai"
        "aerospace"
        "none"
      ];
      default = "yabai";
      description = "Which window manager to use";
    };
  };

  config = {
    # Yabai service configuration
    services.yabai = {
      enable = cfg.backend == "yabai";
      package = pkgs.yabai;
      enableScriptingAddition = cfg.backend == "yabai";
    };

    # Skhd service configuration
    services.skhd = {
      enable = cfg.backend == "yabai";
    };

    # AeroSpace via homebrew (only when aerospace backend)
    homebrew.casks = lib.mkIf (cfg.backend == "aerospace") [ "aerospace" ];

    # Launchd logging for yabai/skhd (only when yabai backend)
    launchd.user.agents = lib.mkIf (cfg.backend == "yabai") {
      yabai.serviceConfig = {
        StandardOutPath = "/tmp/yabai.log";
        StandardErrorPath = "/tmp/yabai.log";
      };
      skhd.serviceConfig = {
        StandardOutPath = "/tmp/skhd.log";
        StandardErrorPath = "/tmp/skhd.log";
      };
    };
  };
}
