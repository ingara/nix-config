# Hyprland home-manager bundle for Linux desktop hosts.
#
# Gated on `"hyprland"` ∈ `myOptions.windowManager.enabled`. Import this module
# explicitly in a per-host HM import list; do NOT add it to the shared
# linux/home-manager.nix — that module is also used by headless servers
# which have no use for Wayland desktop packages.
#
# System-layer prerequisite (on the consuming host's NixOS config):
# `programs.hyprland.enable = true`, so the session is registered and
# xdg-desktop-portal-hyprland is wired. This module sets package = null /
# portalPackage = null to consume that system Hyprland and avoid version skew.
#
# Scope: the compositor itself plus Hyprland-coupled tooling (hyprshell,
# grimblast/satty). WM-agnostic session plumbing (launcher, polkit agent,
# cursor, cross-WM Stylix targets) lives in wm-common.nix; the desktop shell
# (Noctalia or the composable waybar/mako/… stack) is layered on per-host.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  wm = config.myOptions.windowManager;
  # base16 accents for satty's annotation swatches. satty wants RRGGBBAA, so
  # pin full opacity. The editor *chrome* is GTK4/libadwaita and already follows
  # stylix.targets.gtk; only this palette needs explicit base16 wiring (no
  # hardcoded hex — repo theming rule).
  c = config.lib.stylix.colors;
  sattyPalette = map (h: "#${h}ff") [
    c.base08 # red
    c.base09 # orange
    c.base0A # yellow
    c.base0B # green
    c.base0D # blue
    c.base0E # magenta
  ];

  gamesWorkspace = "2";

  lua = lib.generators.mkLuaInline;
  bind = key: action: {
    _args = [
      key
      (lua "hl.dsp.${action}")
    ];
  };
  exec = key: command: bind key "exec_cmd(${builtins.toJSON command})";

in
lib.mkIf (lib.elem "hyprland" wm.enabled) {
  # Screenshots: grimblast is a self-contained grim+slurp+hyprctl wrapper
  # (it bundles its own grim/slurp/wl-clipboard via wrapper PATH); satty is
  # the post-capture editor. wl-clipboard is here for satty's copy-command.
  # Standalone CLIs, NOT a compositor plugin — no Hyprland-ABI coupling
  # (same reasoning that picked hyprshell over plugin-based switchers).
  # playerctl for the media-key binds comes from wm-common.nix.
  home.packages = [
    pkgs.grimblast
    pkgs.wl-clipboard
  ];

  # satty — the Shottr-style capture editor: a grab pops it open, then Enter
  # copies (your macOS cmd+c muscle memory) or Ctrl+S saves. early-exit closes
  # it right after the action. Config → ~/.config/satty/config.toml.
  programs.satty = {
    enable = true;
    settings = {
      general = {
        copy-command = "wl-copy";
        output-filename = "~/Pictures/Screenshots/shot-%Y-%m-%d_%H-%M-%S.png";
        early-exit = [ "all" ]; # close after copy/save
        actions-on-enter = [ "save-to-clipboard" ]; # Enter = copy
        initial-tool = "arrow";
      };
      color-palette.palette = sattyPalette;
    };
  };

  # hyprshell — GTK4 window switcher + workspace overview driven by Hyprland IPC.
  # It is a standalone app, NOT a compositor plugin, so it carries no ABI-match
  # risk against the system Hyprland (unlike hyprexpo/hyprspace/the archived
  # hycov). IPC compatibility still matters: 4.10.8 supports the Lua manager.
  #
  # It self-registers its keybinds from config.json (no Hyprland `bind` lines
  # here — a static bind on the same key would collide):
  #   - Switch  (hold Alt + Tab to cycle windows, release Alt to select) — the
  #     Windows-style alt-tab. Owns Alt+Tab.
  #   - Overview (Super + Tab) — expose all workspaces with live previews.
  #
  # Theming: uses hyprshell's built-in GTK theme. There is no Stylix target; a
  # base16 `style` (CSS from config.lib.stylix.colors) is a deliberate follow-up.
  services.hyprshell = {
    enable = true;
    systemd.enable = true; # runs `hyprshell run` under the wayland session
    settings = {
      version = 4;
      windows = {
        switch.modifier = "alt";
        overview = {
          modifier = "super";
          key = "tab";
        };
      };
    };
  };

  # Stylix merges colours into settings.config for the Lua config manager.
  stylix.targets.hyprland.enable = true;

  wayland.windowManager.hyprland = {
    enable = true;
    package = null; # use the system Hyprland (programs.hyprland) — avoid version skew
    portalPackage = null; # likewise xdg-desktop-portal-hyprland
    configType = "lua";

    # UWSM owns graphical-session.target. HM must not independently stop it
    # through hyprland-session.target; session units follow UWSM's lifecycle.
    systemd.enable = false;

    settings = {
      # Native games have arbitrary classes; SteamGameId is scoped to their process tree.
      # open_early precedes layout attachment, which the float dispatcher requires.
      on = [
        {
          _args = [
            "window.open"
            (lua ''
              function(window)
                local pid = window.pid
                if not pid or pid <= 0 then return end
                -- Synchronous proc IO may stall the compositor; accept this for a just-mapped process.
                local file = io.open("/proc/" .. pid .. "/environ", "rb")
                if not file then return end
                local environ = file:read("*a")
                file:close()
                if not environ then return end
                if not environ:match("^SteamGameId=")
                  and not environ:find("\0SteamGameId=", 1, true) then return end
                hl.dispatch(hl.dsp.window.float({ action = "on", window = window }))
                hl.dispatch(hl.dsp.window.move({ workspace = ${gamesWorkspace}, window = window }))
                -- Floating keeps the window's scrolling-tape position, which can be off-screen.
                hl.dispatch(hl.dsp.window.center({ window = window }))
              end
            '')
          ];
        }
      ];

      env = map (args: { _args = args; }) [
        [
          "LIBVA_DRIVER_NAME"
          "nvidia"
        ]
        [
          "__GLX_VENDOR_LIBRARY_NAME"
          "nvidia"
        ]
        [
          "NVD_BACKEND"
          "direct"
        ]
      ];

      config = {
        cursor = {
          # NVIDIA cursor planes are unreliable; keep pointer and keyboard focus independent.
          no_hardware_cursors = true;
          no_warps = true;
        };
        input = {
          # Hover/scroll reaches an unfocused window without moving keyboard focus.
          follow_mouse = 2;
          float_switch_override_focus = 0;
        };
        misc = {
          mouse_move_focuses_monitor = false;
          # Drop to 2 (fullscreen-only) if always-on VRR causes desktop flicker.
          vrr = 1;
        };
        animations.enabled = true;
        general = {
          layout = "scrolling";
          border_size = 3;
        };
        decoration.rounding = 8;
        # +conf wraps: two entries make Mod+W a half/full toggle.
        scrolling.explicit_column_widths = "0.5, 1.0";
        # Give XWayland games native pixels, accepting small desktop X11 UIs.
        xwayland.force_zero_scaling = true;
      };

      # Non-overshooting curves keep short animations crisp without springy motion.
      curve = [
        {
          _args = [
            "easeOut"
            {
              type = "bezier";
              points = [
                [
                  0.16
                  1
                ]
                [
                  0.3
                  1
                ]
              ];
            }
          ];
        }
        {
          _args = [
            "snappy"
            {
              type = "bezier";
              points = [
                [
                  0.2
                  1
                ]
                [
                  0.2
                  1
                ]
              ];
            }
          ];
        }
      ];
      animation = [
        {
          leaf = "windows";
          enabled = true;
          speed = 3;
          bezier = "easeOut";
          style = "slide";
        }
        {
          leaf = "windowsOut";
          enabled = true;
          speed = 3;
          bezier = "easeOut";
          style = "slide";
        }
        {
          leaf = "border";
          enabled = true;
          speed = 5;
          bezier = "default";
        }
        {
          leaf = "fade";
          enabled = true;
          speed = 3;
          bezier = "easeOut";
        }
        {
          leaf = "workspaces";
          enabled = true;
          speed = 4;
          bezier = "snappy";
          style = "slide";
        }
      ];

      # Primary: native 4K/240, 10-bit SDR. HDR stays per-game via gamescope.
      # 3840/1.2=3200, 2160/1.2=1800 logical pixels; secondary y=1800 avoids overlap.
      monitor = [
        {
          output = "DP-3";
          mode = "3840x2160@240";
          position = "0x0";
          scale = 1.2;
          bitdepth = 10;
        }
        {
          output = "DP-2";
          mode = "2560x1600@120";
          position = "0x1800";
          scale = 1.25;
        }
        {
          output = "";
          mode = "preferred";
          position = "auto";
          scale = 1;
        }
      ];
      # Only desktop + games on primary; other numbered workspaces on secondary.
      workspace_rule = [
        {
          workspace = "1";
          monitor = "DP-3";
          default = true;
        }
        {
          workspace = gamesWorkspace;
          monitor = "DP-3";
        }
        {
          workspace = "3";
          monitor = "DP-2";
          default = true;
        }
      ]
      ++ map (n: {
        workspace = toString n;
        monitor = "DP-2";
      }) (lib.range 4 9);

      # Match before mapping; the environment handler catches native games with unknown classes.
      # Floating games on their own workspace keeps focus-loss fullscreen drops off the tiling tape.
      window_rule = [
        {
          name = "steam-games";
          match.class = "^(steam_app_[0-9]+|gamescope)$";
          float = true;
          workspace = gamesWorkspace;
        }
      ];

      terminal._var = "ghostty";
      termmux._var = "ghostty -e tmux new -A -s main";
      # Kept as a merged setting so the desktop-shell module can override it.
      menu._var = lib.mkDefault "fuzzel";

      bind = [
        (bind "ALT + Return" "exec_cmd(terminal)")
        (bind "ALT + SHIFT + Return" "exec_cmd(termmux)")
        (bind "ALT + Space" "exec_cmd(menu)")
        # Wayland blocks global key grabs, so drive 1Password Quick Access through its CLI.
        (exec "ALT + SHIFT + Space" "1password --quick-access")
        (bind "ALT + Q" "window.close()")
        # SIGKILL the focused PID when an app cannot handle a graceful close.
        (bind "ALT + SHIFT + Q" "window.kill()")
        (bind "ALT + SHIFT + E" "exit()")
        (bind "ALT + SHIFT + F" "window.fullscreen()")
        (bind "ALT + G" "window.float({ action = 'toggle' })")

        # Region / active window → satty; monitor → clipboard.
        (exec "Print" "grimblast --freeze save area - | satty --filename -")
        (exec "ALT + Print" "grimblast save active - | satty --filename -")
        (exec "ALT + SHIFT + Print" "grimblast --notify copy output")
        (bind "ALT + X" "focus({ last = true })")

        # The scrolling layout has no height-resize or standalone center action.
        (bind "ALT + minus" "layout('colresize -0.1')")
        (bind "ALT + equal" "layout('colresize +0.1')")
        (bind "ALT + comma" "layout('consume')")
        (bind "ALT + period" "layout('expel')")
        (bind "ALT + W" "layout('colresize +conf')")
        (bind "ALT + M" "focus({ monitor = '+1' })")
        (bind "ALT + N" "focus({ monitor = '-1' })")
        (bind "ALT + SHIFT + M" "window.move({ monitor = '+1' })")
        (bind "ALT + SHIFT + N" "window.move({ monitor = '-1' })")
      ]
      # Alt+Tab and Super+Tab belong to hyprshell; do not duplicate its grabs.
      ++
        lib.concatMap
          (entry: [
            (bind "ALT + ${entry.key}" "focus({ direction = '${entry.direction}' })")
            (bind "ALT + SHIFT + ${entry.key}" "window.move({ direction = '${entry.direction}' })")
          ])
          [
            {
              key = "H";
              direction = "left";
            }
            {
              key = "J";
              direction = "down";
            }
            {
              key = "K";
              direction = "up";
            }
            {
              key = "L";
              direction = "right";
            }
            {
              key = "A";
              direction = "left";
            }
            {
              key = "D";
              direction = "right";
            }
          ]
      ++ lib.concatMap (n: [
        (bind "ALT + ${toString n}" "focus({ workspace = ${toString n} })")
        (bind "ALT + SHIFT + ${toString n}" "window.move({ workspace = ${toString n} })")
      ]) (lib.range 1 9)
      # Media keys work while locked, without adding key repeat.
      ++
        map
          (entry: {
            _args = [
              entry.key
              (lua "hl.dsp.exec_cmd(${builtins.toJSON entry.command})")
              { locked = true; }
            ];
          })
          [
            {
              key = "XF86AudioPlay";
              command = "playerctl play-pause";
            }
            {
              key = "XF86AudioPause";
              command = "playerctl play-pause";
            }
            {
              key = "XF86AudioNext";
              command = "playerctl next";
            }
            {
              key = "XF86AudioPrev";
              command = "playerctl previous";
            }
            {
              key = "XF86AudioRaiseVolume";
              command = "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+";
            }
            {
              key = "XF86AudioLowerVolume";
              command = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
            }
            {
              key = "XF86AudioMute";
              command = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
            }
            {
              key = "XF86AudioMicMute";
              command = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
            }
          ];
    };
  };
}
