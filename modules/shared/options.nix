{ lib, ... }:
let
  # Selectable window managers (darwin: yabai..nehir; linux: hyprland/niri),
  # partitioned by class in _wm-names.nix — the single source for the
  # windowManager `enabled`/`default` enums below and the per-class validity
  # assertion in home/default.nix, so adding a WM is one edit there.
  wmClasses = import ./_wm-names.nix;
  wmNames = wmClasses.darwin ++ wmClasses.linux;
in
{
  options.myOptions = {
    user = {
      username = lib.mkOption {
        type = lib.types.str;
        default = "user";
      };
      fullName = lib.mkOption {
        type = lib.types.str;
        default = "Nix User";
      };
      email = lib.mkOption {
        type = lib.types.str;
        default = "user@example.com";
      };
      signingKey = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
    };
    dotfiles = {
      repoRoot = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Root path of the nix-config repo, used for dotfile symlinks";
      };
    };
    opencode = {
      hostClass = lib.mkOption {
        type = lib.types.enum [
          "workstation"
          "server"
        ];
        default = "workstation";
        description = ''
          Selects which opencode permission profile is symlinked to
          ~/.config/opencode/opencode.json. "server" adds outbound
          network/exec denies (ssh/scp/rsync/nc) and shutdown/reboot denies
          on top of the workstation profile.
        '';
      };
    };
    hasGui = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    windowManager = {
      # Set+default model. `enabled` = which WMs are installed and configured
      # (casks installed, dotfiles rendered, services declared); `default` =
      # the active/login WM (drives the /etc/nix-config/wm-backend marker and
      # single-active surfaces like yabai's scripting addition). Both scopes
      # (system + HM) on both platforms read this; per-platform modules gate on
      # `elem` membership. Darwin WMs: yabai/aerospace/omniwm/paneru/nehir;
      # Linux WMs: hyprland/niri. The per-class validity rule (no darwin WM in
      # `enabled` on Linux, and `default ∈ enabled`) is enforced by assertions
      # in shared/home/default.nix, not by type narrowing.
      #
      # Multi-WM *run-one*: for the open-a-lifecycle WMs (nehir/omniwm) a 2+
      # `enabled` list installs all of them, and a single `wm-autostart` agent
      # runs `wm-switch <default>` at login to launch exactly one (see
      # modules/darwin/window-manager.nix). yabai self-starts via services.yabai.
      enabled = lib.mkOption {
        type = lib.types.listOf (lib.types.enum wmNames);
        default = [ ];
        description = ''
          Window managers to install and configure. Each WM module self-gates
          on membership here; multiple may be installed at once, with `default`
          selecting the active one.
        '';
      };
      default = lib.mkOption {
        type = lib.types.enum (wmNames ++ [ "none" ]);
        default = "none";
        description = ''
          The active/login window manager (must be "none" or a member of
          `enabled`). Drives the /etc/nix-config/wm-backend marker.
        '';
      };
    };
    mutableDotfiles = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    zellijAutoAttach = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    sshSignProgram = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    gitCredentialHelper = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    claudeCode = {
      extraManagedSettings = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = ''
          Per-host / private additions merged (via lib.recursiveUpdate)
          into the Nix-baked Claude Code managed-settings.json. The public
          module sets generic policy + stable preference scalars; private
          or host-specific keys (enabledPlugins, extraKnownMarketplaces,
          statusLine, autoMode trust hints, claudeMd) are injected here so
          they stay out of the public module. Highest-precedence scope:
          keys set here cannot be overridden by Claude's in-app UI.
        '';
      };

      ownStatusLine = lib.mkEnableOption ''
        a locally-built statusLine command in place of invoking a renderer
        directly. Claude Code gives the statusLine a single command slot, so
        anything that needs to observe the same payload — usage collectors,
        extra segments — has to be composed behind one entry point.

        Declared here rather than beside its implementation because the whole
        myOptions tree is forwarded into home-manager, so an option only the
        system scope knows about breaks HM's copy of it. Off by default: such a
        wrapper carries whatever it composes, which is closure a host that only
        needs the renderer should not hold
      '';
    };
    codex = {
      extraSystemConfig = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = ''
          Per-host / private additions merged (via lib.recursiveUpdate) into
          the Nix-baked /etc/codex/config.toml. The public module sets generic
          policy; permission profiles are injected here, since a profile
          encodes which paths one workflow needs to write.

          A profile set here MUST define `extends`. Codex accepts a profile
          table without one, then aborts — SIGABRT, exit 134, nothing on
          stdout or stderr — the moment that profile is selected.
        '';
      };
    };
    theme = {
      scheme = lib.mkOption {
        type = lib.types.enum [
          "rose-pine"
          "rose-pine-moon"
          "rose-pine-dawn"
          "tokyo-night-dark"
          "tokyo-night-storm"
          "tokyo-night-moon"
          "tokyo-night-light"
          "kanagawa"
          "kanagawa-dragon"
        ];
        default = "rose-pine-moon";
        description = ''
          Active base16 color scheme. Drives Stylix across every themed
          surface (terminals, editors, status bars, GTK/Qt, KDE Plasma,
          cursors). Scheme names map 1:1 to YAML files in
          inputs.tinted-schemes/base16/<name>.yaml.
        '';
      };
      polarity = lib.mkOption {
        type = lib.types.enum [
          "light"
          "dark"
          "either"
        ];
        default = "dark";
        description = ''
          Forces light or dark variants where the target app supports
          both, or "either" to let Stylix pick.
        '';
      };
    };
  };
}
