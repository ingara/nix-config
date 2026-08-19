# niri home-manager bundle for Linux desktop hosts — the second Linux WM,
# alongside Hyprland (which stays the login default where both are enabled).
#
# Gated on `"niri"` ∈ `myOptions.windowManager.enabled`. Import this module
# explicitly in a per-host HM import list (the graphical role's home slot); do
# NOT add it to the shared linux/home-manager.nix — that module is also used by
# headless servers.
#
# System-layer prerequisite (on the consuming host's NixOS config):
# `programs.niri.enable = true`, which registers the session (niri-session),
# wires the gnome+gtk portals, and installs the compositor binary. This module
# renders only ~/.config/niri/config.kdl — the session binary always comes from
# the system layer, so there is no HM/system version skew to manage.
#
# There is no home-manager niri module and no Stylix niri target at our locked
# revs, so the config is a Nix-generated KDL file: keybinds follow the
# cross-WM keybind convention (Mod = Alt), colors come from
# config.lib.stylix.colors, and `niri validate` gates the file at build time —
# a config typo fails the build instead of the next login.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  wm = config.myOptions.windowManager;
  cfg = config.myOptions.niri;
  c = config.lib.stylix.colors.withHashtag;
  # Cursor theme is owned by stylix.cursor (home.pointerCursor); mirror it into
  # niri's own cursor block so the compositor cursor matches GTK/XWayland
  # instead of falling back to the default theme.
  cursor = config.home.pointerCursor;

  # Workspace binds as one map so the focus/move pair can't drift out of sync.
  # move-window-to-workspace (not -column-) matches Hyprland's movetoworkspace
  # semantics: the focused window moves, the rest of its column stays. Known
  # divergence: niri workspaces are DYNAMIC per-monitor indices (they renumber
  # as workspaces empty; past-the-end lands on the last, empty one), not
  # Hyprland's stable numbered set — accepted as the niri model. Plain strings
  # (not '') so the leading KDL indentation survives interpolation.
  workspaceBinds = lib.concatMapStrings (
    n:
    "    Alt+${toString n} { focus-workspace ${toString n}; }\n"
    + "    Alt+Shift+${toString n} { move-window-to-workspace ${toString n}; }\n"
  ) (lib.range 1 9);

  configKdl = pkgs.writeText "niri-config.kdl" ''
    input {
        keyboard {
            xkb {
                ${lib.optionalString (cfg.keyboardLayout != null) ''layout "${cfg.keyboardLayout}"''}
            }
        }
    }

    // NVIDIA userspace pins, same set as the Hyprland config. Scope caveat:
    // this block reaches ONLY processes niri itself spawns (spawn/spawn-sh
    // binds) — it does NOT propagate to the systemd user environment, so apps
    // launched via a systemd-managed shell (Noctalia's launcher) miss these.
    // Same split as the Hyprland session (its env block is equally
    // compositor-scoped); promote to session-wide env at the nvidia layer if
    // that bites on-box. No AQ_DRM_DEVICES: Aquamarine is Hyprland's backend —
    // niri (Smithay) does its own GPU selection.
    environment {
        LIBVA_DRIVER_NAME "nvidia"
        __GLX_VENDOR_LIBRARY_NAME "nvidia"
        NVD_BACKEND "direct"
    }

    ${lib.optionalString (cursor != null) ''
      cursor {
          xcursor-theme "${cursor.name}"
          xcursor-size ${toString cursor.size}
      }
    ''}

    // Same layout and scaling as the Hyprland monitor config (Noctalia's
    // shared bar/shell sizing assumes both sessions scale DP-3 identically):
    // G8 (DP-3) native 4K@240 primary at 1.2 scale, secondary (DP-2) directly
    // below — y=1800 is the primary's logical height — at 1.25 scale. Refresh
    // rates are left to "highest for the resolution" — an exact @240 that
    // doesn't match the modeline to the decimal would be silently replaced by
    // an auto-pick anyway. VRR goes on the G8 only (niri's VRR is per-output,
    // so Hyprland's global-vs-fullscreen vrr trade-off doesn't apply); 10-bit
    // has no niri config surface — an accepted gap vs the Hyprland session.
    output "DP-3" {
        mode "3840x2160"
        position x=0 y=0
        scale 1.2
        variable-refresh-rate
    }
    output "DP-2" {
        mode "2560x1600"
        position x=0 y=1800
        scale 1.25
    }

    layout {
        focus-ring {
            width 4
            active-color "${c.base0D}"
            inactive-color "${c.base03}"
        }
        default-column-width { proportion 0.5; }
    }

    // Tiled windows shouldn't draw their own decorations; also lets niri draw
    // the focus ring around (not behind) semitransparent windows.
    prefer-no-csd

    // Matches the satty save pattern under Hyprland, so both sessions drop
    // screenshots in the same place.
    screenshot-path "~/Pictures/Screenshots/shot-%Y-%m-%d_%H-%M-%S.png"

    // The hotkey list stays reachable on Alt+Shift+/ below.
    hotkey-overlay {
        skip-at-startup
    }

    // Keybinds per the cross-WM convention (Mod = Alt), mirroring the Hyprland
    // config. Unlike most sections, `binds` gets NO defaults when omitted —
    // this list is the complete set. niri closes two documented Hyprland
    // scrolling-layout gaps (height resize, center) and adds preset widths and
    // tabbed columns; there is no forcekillactive analog (accepted gap).
    binds {
        Alt+Return { spawn "ghostty"; }
        // spawn takes a literal argv, hence the split tmux args (vs spawn-sh).
        Alt+Shift+Return { spawn "ghostty" "-e" "tmux" "new" "-A" "-s" "main"; }
        Alt+Space { spawn-sh "${cfg.menu}"; }
        // Wayland blocks apps from grabbing global keys, so 1Password's own
        // shortcut is dead — drive it via CLI (same as the Hyprland bind).
        Alt+Shift+Space { spawn-sh "1password --quick-access"; }
        Alt+Q repeat=false { close-window; }
        // quit shows a confirmation dialog — a deliberate divergence from
        // Hyprland's instant exit.
        Alt+Shift+E { quit; }
        Alt+F { fullscreen-window; }
        Alt+G { toggle-window-floating; }

        // Screenshots: niri's built-in UI (select region/window, Enter copies,
        // saves to screenshot-path). grimblast+satty are Hyprland-coupled
        // (grimblast drives hyprctl), so the annotate-in-satty flow is
        // Hyprland-session-only.
        Print { screenshot; }
        Alt+Print { screenshot-window; }
        Alt+Shift+Print { screenshot-screen; }

        // Focus — Alt+hjkl: left/right between columns, up/down within one.
        Alt+H { focus-column-left; }
        Alt+J { focus-window-down; }
        Alt+K { focus-window-up; }
        Alt+L { focus-column-right; }
        // Left-hand aliases for the horizontal pair, same as the Hyprland session.
        Alt+A { focus-column-left; }
        Alt+D { focus-column-right; }
        Alt+X { focus-window-previous; }
        // Alt+Tab is deliberately NOT bound here: niri's built-in
        // recent-windows MRU switcher (on by default) owns Alt+Tab /
        // Alt+Shift+Tab — the hyprshell role under Hyprland. A general bind on
        // the same key would shadow it. Overview rides Super+Tab per the
        // convention (shadowing the switcher's Mod+Tab default).
        Super+Tab repeat=false { toggle-overview; }
        Alt+U { focus-column-first; }
        Alt+O { focus-column-last; }

        // Move — Alt+Shift+hjkl: reorder columns h/l, move within a column j/k.
        Alt+Shift+H { move-column-left; }
        Alt+Shift+J { move-window-down; }
        Alt+Shift+K { move-window-up; }
        Alt+Shift+L { move-column-right; }
        Alt+Shift+A { move-column-left; }
        Alt+Shift+D { move-column-right; }

        // Monitor nav — Alt+m/n focus, Alt+Shift+m/n move. Window-tier moves
        // (not -column-) to match Hyprland's `movewindow mon:±1`.
        Alt+M { focus-monitor-next; }
        Alt+N { focus-monitor-previous; }
        Alt+Shift+M { move-window-to-monitor-next; }
        Alt+Shift+N { move-window-to-monitor-previous; }

        // Workspace next/prev — niri workspaces are a vertical strip.
        Ctrl+Alt+J { focus-workspace-down; }
        Ctrl+Alt+K { focus-workspace-up; }

        // Column ops per the convention: consume/expel on ,/. , width on -/=,
        // height on Shift+-/=, presets on r, center on c, full-width on w,
        // tabbed on t.
        Alt+Comma { consume-window-into-column; }
        Alt+Period { expel-window-from-column; }
        Alt+Minus { set-column-width "-10%"; }
        Alt+Equal { set-column-width "+10%"; }
        Alt+Shift+Minus { set-window-height "-10%"; }
        Alt+Shift+Equal { set-window-height "+10%"; }
        Alt+R { switch-preset-column-width; }
        Alt+Shift+R { switch-preset-column-width-back; }
        Alt+C { center-column; }
        Alt+W { maximize-column; }
        Alt+T { toggle-column-tabbed-display; }

        Alt+Shift+Slash { show-hotkey-overlay; }
        // Escape hatch for the shortcuts-inhibit protocol (remote-desktop /
        // software-KVM apps can request niri stop processing these binds) —
        // allow-inhibiting=false so a buggy client can't hold the session.
        Alt+Escape allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }

    ${workspaceBinds}
        // Media + volume keys, same commands as the Hyprland bindl set;
        // allow-when-locked is niri's equivalent of the `l` flag.
        XF86AudioPlay allow-when-locked=true { spawn-sh "playerctl play-pause"; }
        XF86AudioPause allow-when-locked=true { spawn-sh "playerctl play-pause"; }
        XF86AudioNext allow-when-locked=true { spawn-sh "playerctl next"; }
        XF86AudioPrev allow-when-locked=true { spawn-sh "playerctl previous"; }
        XF86AudioRaiseVolume allow-when-locked=true { spawn-sh "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"; }
        XF86AudioMute allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"; }
        XF86AudioMicMute allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"; }
    }
  '';

  # Parse-gate the generated KDL at build time. pkgs.niri here is build-time
  # only (nothing lands in home.packages) and resolves to the same derivation
  # as the system compositor — one nixpkgs, one niri.
  validatedConfig =
    pkgs.runCommand "niri-config-validated.kdl"
      {
        nativeBuildInputs = [ pkgs.niri ];
      }
      ''
        niri validate --config ${configKdl}
        cp ${configKdl} $out
      '';
in
{
  options.myOptions.niri = {
    keyboardLayout = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        XKB layout name for the niri session (e.g. a custom
        services.xserver.xkb.extraLayouts entry). null leaves the xkb section
        empty, so niri falls back to org.freedesktop.locale1.
      '';
    };
    menu = lib.mkOption {
      type = lib.types.str;
      default = "fuzzel";
      description = ''
        Launcher command for Alt+Space (run via spawn-sh). A per-host desktop
        shell overrides this with its own launcher; fuzzel stays installed as
        the shell-independent fallback.
      '';
    };
  };

  # The WM-agnostic session plumbing (launcher, polkit agent, cursor theme,
  # playerctl, cross-WM Stylix targets, the screenshot dir) comes from
  # wm-common.nix — this module renders only the niri config itself.
  config = lib.mkIf (lib.elem "niri" wm.enabled) {
    xdg.configFile."niri/config.kdl".source = validatedConfig;
  };
}
