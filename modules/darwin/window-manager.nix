{
  config,
  pkgs,
  lib,
  ...
}:

let
  # `enabled` selects installed WMs; `default` is the login choice. A manual
  # switch changes only runtime state, not this option.
  cfg = config.myOptions.windowManager;
  dots = import ../shared/home/lib/dotfiles.nix { inherit lib; };

  # Multi-WM run-one (design §3.3). nehir/omniwm are LSUIElement GUI `.app`
  # casks: their lifecycle is LaunchServices (`open -a`) + AppleScript quit, NOT
  # a bare-binary launchd agent (which loses Accessibility/TCC context and would
  # double-launch nehir's self-registered login item). So instead of per-WM
  # agents we ship one `wm-switch` script + a single autostart agent that runs
  # `wm-switch <default>` at login. yabai/aerospace/paneru have other lifecycles
  # and are intentionally absent from this map (deny-by-default: a WM not listed
  # here isn't switchable via wm-switch).
  knownApp = {
    nehir = "Nehir";
    omniwm = "OmniWM";
  };
  # The enabled WMs we can drive via open-a, in `enabled` order.
  switchable = lib.filter (w: knownApp ? ${w}) cfg.enabled;
  # Keep the logical backend key stable while following Nehir's 0.6 release
  # candidates at the Homebrew boundary.
  switchableCasks = map (w: if w == "nehir" then "nehir@rc" else w) switchable;
  enabledBash = lib.concatStringsSep " " switchable;
  # Detect a previously enabled app still running across a configuration
  # change, even if it is no longer eligible as a target.
  known = lib.attrNames knownApp;
  knownBash = lib.concatStringsSep " " known;
  # Quote each array element so a multi-word app name (none today) stays one value.
  appAssoc = lib.concatStringsSep " " (map (w: ''["${w}"]="${knownApp.${w}}"'') known);

  # Run-one lifecycle: exact /Applications casks, serialized quit-then-open,
  # bounded state/IPC checks, and rollback if the new manager cannot start.
  # The script also selects the only active WM-specific skhd layer; `default`
  # still returns at login. Launchd's PATH is minimal, so use absolute tools.
  wmSwitch = pkgs.writeShellApplication {
    name = "wm-switch";
    text = ''
      ENABLED=( ${enabledBash} )
      KNOWN=( ${knownBash} )
      declare -A APP=( ${appAssoc} )
    ''
    + builtins.readFile ./wm-switch.sh;
  };
in
{
  config = {
    # yabai/aerospace dotfiles — clean dirs, so a whole-dir symlink (this module
    # owns its WMs' config). Darwin-only by import path, so no isDarwin guard
    # needed; gated on membership in `enabled`.
    home-manager.sharedModules = [
      (
        { config, lib, ... }:
        let
          wm = config.myOptions.windowManager;
          mkDir =
            srcRel:
            dots.mkDirSymlink {
              inherit config srcRel;
              xdgRel = srcRel;
            };
        in
        {
          # `wm-switch` only supports hosts whose default uses this run-one
          # lifecycle. A secondary cask beside yabai/aerospace cannot be
          # safely switched while that different manager is running.
          home.packages = lib.optionals (lib.elem cfg.default switchable) [ wmSwitch ];
          xdg.configFile =
            lib.optionalAttrs (lib.elem "yabai" wm.enabled) (mkDir "yabai")
            // lib.optionalAttrs (lib.elem "aerospace" wm.enabled) (mkDir "aerospace");
        }
      )
    ];

    # Configured login default for `just _post-switch-darwin` and `just restart-wm`;
    # a manual wm-switch selection does not change this marker.
    environment.etc."nix-config/wm-backend".text = cfg.default;

    # Yabai service + scripting addition only when yabai is the active WM (the
    # SA carries a SIP-exception / sudoers cost — only pay it when it runs).
    services.yabai = {
      enable = cfg.default == "yabai";
      package = pkgs.yabai;
      enableScriptingAddition = cfg.default == "yabai";
    };

    # Install a cask for every enabled cask-based WM (install-many / run-one).
    # paneru is NOT a cask — it installs via services.paneru in paneru.nix.
    homebrew.casks =
      lib.optionals (lib.elem "aerospace" cfg.enabled) [ "aerospace" ] ++ switchableCasks;

    launchd.user.agents = lib.mkMerge [
      # Launchd logging for yabai (only when yabai is active)
      (lib.mkIf (cfg.default == "yabai") {
        yabai.serviceConfig = {
          StandardOutPath = "/tmp/yabai.log";
          StandardErrorPath = "/tmp/yabai.log";
        };
      })

      # Run-one autostart: launch `default` via wm-switch at login. A
      # switchable cask on a host with another default has no run-one agent.
      (lib.mkIf (lib.elem cfg.default switchable) {
        wm-autostart.serviceConfig = {
          ProgramArguments = [
            "${wmSwitch}/bin/wm-switch"
            cfg.default
          ];
          RunAtLoad = true;
          StandardOutPath = "/tmp/wm-autostart.log";
          StandardErrorPath = "/tmp/wm-autostart.log";
        };
      })
    ];
  };
}
