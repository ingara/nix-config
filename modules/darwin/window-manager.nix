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
        "omniwm"
        "none"
      ];
      default = "yabai";
      description = "Which window manager to use";
    };
  };

  config = {
    # Marker file consumed by `just _post-switch-darwin` to decide
    # whether to run yabai-specific post-switch steps. Avoids a slow
    # `nix eval` and a fragile regex-grep of this file at recipe time.
    environment.etc."nix-config/wm-backend".text = cfg.backend;

    # Yabai service configuration
    services.yabai = {
      enable = cfg.backend == "yabai";
      package = pkgs.yabai;
      enableScriptingAddition = cfg.backend == "yabai";
    };

    # AeroSpace via homebrew (only when aerospace backend)
    homebrew.casks =
      lib.optionals (cfg.backend == "aerospace") [ "aerospace" ]
      ++ lib.optionals (cfg.backend == "omniwm") [ "omniwm" ];

    # Launchd logging for yabai (only when yabai backend)
    launchd.user.agents = lib.mkIf (cfg.backend == "yabai") {
      yabai.serviceConfig = {
        StandardOutPath = "/tmp/yabai.log";
        StandardErrorPath = "/tmp/yabai.log";
      };
    };
  };
}
