{
  config,
  pkgs,
  lib,
  ...
}:

let
  # `myOptions.windowManager` is declared in modules/shared/options.nix (shared
  # so the HM side reads it too). `enabled` = installed WMs; `default` = active.
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
  enabledBash = lib.concatStringsSep " " switchable;
  # Quote each array element so a multi-word app name (none today) stays one value.
  appAssoc = lib.concatStringsSep " " (map (w: ''["${w}"]="${knownApp.${w}}"'') switchable);

  # `wm-switch <backend>`: quit the other enabled WMs (guarded so a non-running
  # one isn't cold-launched just to be quit — AppleScript `quit` otherwise
  # launches the target), then `open -a` the target. No skhd reload needed for
  # the nehir+omniwm pair: skhdrc statically loads omniwm.skhd whenever omniwm is
  # enabled, and those bindings (→omniwmctl) are inert while omniwm isn't running;
  # nehir uses internal hotkeys. (skhd reloads on config change via skhd.nix's
  # activation hook.) Absolute tool paths — launchd's PATH is minimal. A live
  # switch is transient; `default` is what returns on reboot/redeploy.
  wmSwitch = pkgs.writeShellApplication {
    name = "wm-switch";
    text = ''
      ENABLED=( ${enabledBash} )
      declare -A APP=( ${appAssoc} )

      if [ $# -ne 1 ]; then
        echo "usage: wm-switch <''${ENABLED[*]}>" >&2
        exit 2
      fi
      target="$1"

      in_enabled=0
      for w in "''${ENABLED[@]}"; do [ "$w" = "$target" ] && in_enabled=1; done
      if [ "$in_enabled" != 1 ]; then
        echo "wm-switch: '$target' not in switchable set (''${ENABLED[*]})" >&2
        exit 1
      fi

      # Launch the target FIRST. If it can't launch (cask not yet installed, or
      # not registered with LaunchServices), bail before quitting anything — a
      # failed switch then leaves the current WM running instead of tearing it
      # down with no replacement. `open -a` on an already-running app just
      # focuses it (single-instance), so this is a no-op when target is live.
      if ! /usr/bin/open -a "''${APP[$target]}"; then
        echo "wm-switch: could not launch ''${APP[$target]} (cask installed?) — keeping current WM" >&2
        exit 1
      fi

      # Now quit the other enabled WMs. The `is running` guard keeps a non-running
      # WM from being cold-launched just to receive a quit. pkill -x is the fallback.
      for w in "''${ENABLED[@]}"; do
        [ "$w" = "$target" ] && continue
        app="''${APP[$w]}"
        /usr/bin/osascript -e "if application \"$app\" is running then tell application \"$app\" to quit" >/dev/null 2>&1 \
          || /usr/bin/pkill -x "$app" >/dev/null 2>&1 || true
      done
    '';
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
          # `wm-switch` on the user's PATH for manual runtime switching — only on
          # hosts that actually have a switchable WM (else it would always exit 1).
          home.packages = lib.optionals (switchable != [ ]) [ wmSwitch ];
          xdg.configFile =
            lib.optionalAttrs (lib.elem "yabai" wm.enabled) (mkDir "yabai")
            // lib.optionalAttrs (lib.elem "aerospace" wm.enabled) (mkDir "aerospace");
        }
      )
    ];

    # Marker files consumed by `just _post-switch-darwin` / `just restart-wm`.
    # `wm-backend` is the active WM key (`default`), not the full enabled set;
    # `wm-backend-app` is its LaunchServices app name when `default` is an
    # open-a WM (empty otherwise), letting `restart-wm` quit+reopen it without
    # re-encoding the knownApp map in the justfile. Both avoid a slow `nix eval`
    # and a fragile regex-grep at recipe time.
    environment.etc."nix-config/wm-backend".text = cfg.default;
    environment.etc."nix-config/wm-backend-app".text = lib.optionalString (
      knownApp ? ${cfg.default}
    ) knownApp.${cfg.default};

    # Yabai service + scripting addition only when yabai is the active WM (the
    # SA carries a SIP-exception / sudoers cost — only pay it when it runs).
    services.yabai = {
      enable = cfg.default == "yabai";
      package = pkgs.yabai;
      enableScriptingAddition = cfg.default == "yabai";
    };

    # Install a cask for every enabled cask-based WM (install-many / run-one).
    # paneru is NOT a cask — it installs via services.paneru in paneru.nix.
    # nehir/omniwm: the Homebrew cask name equals the wm-key, so the open-a set
    # (`switchable`) doubles as their cask list — adding an open-a WM is then a
    # single edit to `knownApp`, not here too.
    homebrew.casks = lib.optionals (lib.elem "aerospace" cfg.enabled) [ "aerospace" ] ++ switchable;

    launchd.user.agents = lib.mkMerge [
      # Launchd logging for yabai (only when yabai is active)
      (lib.mkIf (cfg.default == "yabai") {
        yabai.serviceConfig = {
          StandardOutPath = "/tmp/yabai.log";
          StandardErrorPath = "/tmp/yabai.log";
        };
      })

      # Run-one autostart: launch `default` via wm-switch at login. Only for the
      # open-a-lifecycle WMs (knownApp) — yabai self-starts via services.yabai,
      # so no agent here when it's the default.
      (lib.mkIf (knownApp ? ${cfg.default}) {
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
