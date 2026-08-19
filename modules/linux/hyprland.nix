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
in
lib.mkIf (lib.elem "hyprland" wm.enabled) {
  # ghostty (the terminal) is managed by programs.ghostty in shared/home/ghostty.nix
  # — config + theme + the nixpkgs binary on NixOS, enabled on hasGui hosts — so
  # it's deliberately absent from this host's package list.
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
  # hycov) — a hyprland bump can't break it at load. Needs hyprland >= 0.55
  # (system is 0.55.x).
  #
  # It self-registers its keybinds from config.json (no Hyprland `bind` lines
  # here — a static bind on the same key would collide):
  #   - Switch  (hold Alt + Tab to cycle windows, release Alt to select) — the
  #     Windows-style alt-tab. Owns Alt+Tab.
  #   - Overview (Super + Tab) — expose all workspaces with live previews.
  # config `version` is the current schema version.
  #
  # Theming: uses hyprshell's built-in GTK theme. There is no Stylix target; a
  # base16 `style` (CSS from config.lib.stylix.colors) is a deliberate follow-up,
  # not shipped here.
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

  # Compositor-specific Stylix target (the cross-WM ones — fuzzel/gtk/qt/cursor
  # — live in wm-common.nix). Writes colors into
  # wayland.windowManager.hyprland's settings (respecting configType =
  # "hyprlang").
  stylix.targets.hyprland.enable = true;

  wayland.windowManager.hyprland = {
    enable = true;
    package = null; # use the system Hyprland (programs.hyprland) — avoid version skew
    portalPackage = null; # likewise xdg-desktop-portal-hyprland
    configType = "hyprlang"; # pin to hyprlang (proven on the box); HM's default is shifting to "lua"

    # UWSM owns the systemd session (programs.hyprland.withUWSM in
    # nixos/graphical.nix) and only one session manager may run: HM's
    # integration injects `exec-once = … systemctl --user stop
    # hyprland-session.target`, whose PropagatesStopTo=graphical-session.target
    # cascades through uwsm's wayland-session@ binding and kills the compositor
    # mid-login. Nothing is orphaned — every user unit is
    # WantedBy=graphical-session.target, which uwsm starts once Hyprland's
    # `uwsm finalize` has exported the session variables.
    systemd.enable = false;

    settings = {
      env = [
        "LIBVA_DRIVER_NAME,nvidia"
        "__GLX_VENDOR_LIBRARY_NAME,nvidia"
        "NVD_BACKEND,direct"
        # Do NOT set AQ_DRM_DEVICES to a PCI by-path: Aquamarine splits on ':'
        # and a by-path's colons (pci-0000:01:00.0) parse as bad paths → no GPU.
      ];

      cursor = {
        # NVIDIA hardware cursor planes are often broken — render in software.
        no_hardware_cursors = true;
        # No cursor-follows-focus: don't warp the pointer to a window when focus
        # changes via keybind/workspace switch. Pairs with follow_mouse = 2
        # below — the cursor isn't warped on focus change, and hovering doesn't
        # move keyboard focus, so the two stay independent.
        no_warps = true;
      };

      # Detached mouse focus (follow_mouse = 2): the window under the cursor
      # receives pointer events — scroll/hover interact with it — but keyboard
      # focus only moves on click (or via the alt+hjkl binds). Lets you scroll an
      # unfocused window without raising or focusing it. Note hyprshell flips
      # this to 0 transiently while its switcher is open and restores this value.
      input.follow_mouse = 2;

      # Always-on VRR. The G8 is the only output, so global VRR (1) is correct;
      # drop to 2 (fullscreen-only) if a second mixed-refresh output is ever
      # added and the desktop flickers.
      misc.vrr = 1;

      # Animations: snappy ease-out, no bounce. Hyprland's defaults use an
      # *overshoot* bezier (myBezier = 0.05,0.9,0.1,1.05 — the >1.0 final
      # control point is the spring) on ~7-decisecond durations, which reads as
      # bouncy + floaty on a 240Hz panel. easeOut lands cleanly at 1.0 (no
      # overshoot) and short durations (3-4 ds) keep the motion cue without the
      # lag. Durations are in deciseconds; the leading `1` enables each curve.
      animations = {
        enabled = true;
        bezier = [
          "easeOut, 0.16, 1, 0.3, 1"
          "snappy, 0.2, 1, 0.2, 1"
        ];
        animation = [
          "windows, 1, 3, easeOut, slide"
          "windowsOut, 1, 3, easeOut, slide"
          "border, 1, 5, default"
          "fade, 1, 3, easeOut"
          "workspaces, 1, 4, snappy, slide"
        ];
      };

      # Native scrolling layout — built into Hyprland (no plugin). Windows live
      # on a horizontal tape of columns (the niri-like feel). Coarser than niri
      # (no in-column stacking); accepted trade-off vs niri's NVIDIA caveat.
      general.layout = "scrolling";

      # Hyprland's default 1px border is near-invisible on a 4K panel at 1.2 scale.
      general.border_size = 3;
      decoration.rounding = 8;

      # `colresize +conf` picks the first preset strictly greater than the
      # current width, wrapping to the first when there is none — so a
      # two-entry list is a half↔full toggle rather than a cycle. Every ±conf
      # bind shares this one list; lengthening it costs Mod+W its toggle.
      scrolling.explicit_column_widths = "0.5, 1.0";

      # Odyssey G8 (DP-3): native 4K@240, 10-bit, at 1.2 scale for readable
      # text (3840/1.2=3200, 2160/1.2=1800 — clean integer transform). Desktop
      # stays SDR (desktop-wide HDR washes out SDR content); HDR is per-game
      # via gamescope. Secondary (DP-2, 2560x1600@120) sits directly below the
      # primary — y=1800 is the primary's logical height at scale 1.2 — at
      # 1.25 scale (2560/1.25=2048, also clean). The fallback line drives any
      # other display at preferred mode/auto position/scale 1.
      monitor = [
        "DP-3,3840x2160@240,0x0,1.2,bitdepth,10"
        "DP-2,2560x1600@120,0x1800,1.25"
        ",preferred,auto,1"
      ];

      # Hand XWayland clients the monitor's native resolution instead of the
      # scaled logical one — otherwise Hyprland upscales their buffers and
      # every XWayland surface (most Steam games) blurs. Games render
      # pixel-perfect at real 3840x2160; the cost is XWayland *desktop* UIs
      # (Steam's own client) drawing small, which is accepted.
      xwayland.force_zero_scaling = true;

      # The primary (G8) carries only workspaces 1 + 2 — 2 is the dedicated
      # games workspace (see the games windowrule below). Every other numbered
      # workspace (all nine have binds) is pinned to the secondary so nothing
      # else ever opens on the primary by default; one default per monitor
      # keeps the initial layout stable.
      workspace = [
        "1, monitor:DP-3, default:true"
        "2, monitor:DP-3"
        "3, monitor:DP-2, default:true"
      ]
      ++ map (n: "${toString n}, monitor:DP-2") (lib.range 4 9);

      # Steam/Proton (`steam_app_<id>`) and gamescope-wrapped games float and
      # land on workspace 2 instead of joining the scrolling layout. A fullscreen
      # game is otherwise a tiled column underneath, so losing focus (e.g.
      # alt-tabbing to Steam) drops the fullscreen and reveals it half-width
      # beside the other tiled window. Floating keeps it at its own size; the
      # dedicated workspace isolates it (launching a game follows there).
      windowrule = [
        "float on, match:class ^(steam_app_[0-9]+|gamescope)$"
        "workspace 2, match:class ^(steam_app_[0-9]+|gamescope)$"
      ];

      # ALT is the modifier to mirror the macOS workstation (nehir/aerospace)
      # muscle memory: alt+hjkl focus, alt+shift+hjkl move, alt+-/= resize. The
      # cost on Linux is that Hyprland grabs Alt+<key> before apps, shadowing
      # GTK/Qt menu mnemonics (Alt+F File, etc.) and some terminal Alt-word
      # motions for the bound keys — accepted to match the workstation layout.
      "$mod" = "ALT";
      "$terminal" = "ghostty";
      "$termmux" = "ghostty -e tmux new -A -s main";
      # Generic launcher default. A per-host desktop-shell layer (e.g. a
      # Noctalia/Quickshell shell) overrides this to the shell's own launcher;
      # fuzzel stays installed as a shell-independent fallback.
      "$menu" = lib.mkDefault "fuzzel";

      bind = [
        # Core WM actions
        "$mod, Return, exec, $terminal"
        "$mod SHIFT, Return, exec, $termmux"
        "$mod, Space, exec, $menu"
        # 1Password Quick Access. Wayland blocks apps from grabbing global keys,
        # so 1Password's own shortcut is dead under Hyprland — drive it via CLI.
        "$mod SHIFT, Space, exec, 1password --quick-access"
        "$mod, Q, killactive"
        # SIGKILL the focused window's PID directly, for apps too wedged to
        # service the graceful close request killactive sends.
        "$mod SHIFT, Q, forcekillactive"
        "$mod SHIFT, E, exit"
        "$mod, F, fullscreen"
        "$mod, G, togglefloating"

        # Screenshots (Shottr-style: grab → satty editor → Enter copies / Ctrl+S
        # saves to ~/Pictures/Screenshots). --freeze freezes the screen while you
        # drag the region, like the macOS overlay. `save … -` pipes PNG to satty.
        #   Print            region select → editor
        #   $mod+Print       active window → editor
        #   $mod+Shift+Print focused monitor → clipboard (quick path, no editor)
        ", Print, exec, grimblast --freeze save area - | satty --filename -"
        "$mod, Print, exec, grimblast save active - | satty --filename -"
        "$mod SHIFT, Print, exec, grimblast --notify copy output"

        # Focus — alt+hjkl. Under the scrolling layout left/right move between
        # columns, up/down between windows within the focused column.
        "$mod, H, movefocus, l"
        "$mod, J, movefocus, d"
        "$mod, K, movefocus, u"
        "$mod, L, movefocus, r"
        # Left-hand aliases for the horizontal pair. Alt+D is claimed globally
        # as a result — browsers lose address-bar focus, the shell loses
        # kill-word — accepted for the one-handed reach.
        "$mod, A, movefocus, l"
        "$mod, D, movefocus, r"
        "$mod, X, focuscurrentorlast" # alt+x: back-and-forth between two windows
        # NOTE: alt+tab is intentionally NOT bound here — hyprshell (below, in
        # the HM service block) self-registers it as the visual window switcher.
        # A `cyclenext` bind on alt+tab would collide with hyprshell's grab.

        # Move the active window — alt+shift+hjkl. movewindow is layout-generic
        # and supported under scrolling (reorders columns h/l, moves within a
        # column j/k).
        "$mod SHIFT, H, movewindow, l"
        "$mod SHIFT, J, movewindow, d"
        "$mod SHIFT, K, movewindow, u"
        "$mod SHIFT, L, movewindow, r"
        "$mod SHIFT, A, movewindow, l"
        "$mod SHIFT, D, movewindow, r"

        # Resize column width — Mod+-/= (convention resize tier; frees the
        # Ctrl+Alt tier). colresize is the scrolling layout's native width
        # control (relative fraction, ±0.1 ≈ a 10% nudge); resizeactive isn't
        # documented to drive column width under this layout. Height resize has
        # NO scrolling-layout message, so Mod+Shift+-/= (height) is left unbound
        # — a documented gap vs the convention.
        "$mod, minus, layoutmsg, colresize -0.1"
        "$mod, equal, layoutmsg, colresize +0.1"

        # Scrolling-layout column ops (hyprlang `layoutmsg`). consume/expel take
        # no args and ride Mod+,/. per the convention. No viewport-scroll bind:
        # Mod+h/l already scrolls the tape, so `move ±col` is non-canonical.
        # Payloads verified against the scrolling layout source
        # (ScrollingAlgorithm.cpp); the *feel* is tuned on-box.
        "$mod, comma, layoutmsg, consume" # pull window into the column
        "$mod, period, layoutmsg, expel" # push window out to its own column
        # Half↔full toggle, not the cycle the payload name suggests — it rides
        # the two-entry explicit_column_widths above.
        "$mod, W, layoutmsg, colresize +conf"
        # No center bind: the scrolling layout has no standalone center op (the
        # viewport auto-centers on focus via scrolling:focus_fit_method), so the
        # convention's `c` is an accepted Hyprland gap.

        # Monitor nav — Mod+m/n focus, Mod+Shift+m/n move window across monitors
        # (movewindow needs the `mon:` prefix to mean "to monitor", not a
        # direction). focusmonitor takes the relative index directly.
        "$mod, M, focusmonitor, +1"
        "$mod, N, focusmonitor, -1"
        "$mod SHIFT, M, movewindow, mon:+1"
        "$mod SHIFT, N, movewindow, mon:-1"

      ]
      # Workspaces — alt+1..9 focus, alt+shift+1..9 move. Generated as one map so
      # the focus/move pair can't drift out of sync.
      ++ lib.concatMap (n: [
        "$mod, ${toString n}, workspace, ${toString n}"
        "$mod SHIFT, ${toString n}, movetoworkspace, ${toString n}"
      ]) (lib.range 1 9);

      # Media + volume keys. `bindl` (locked) so they fire even when the
      # session is idle/locked — the standard flag for media keys. play/pause
      # talks to the browser's MPRIS player via playerctl; volume/mute go
      # through wpctl (wireplumber, from the system pipewire service).
      #   -l 1.0 caps RaiseVolume at 100% so we can't overdrive past unity.
      bindl = [
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioPause, exec, playerctl play-pause"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPrev, exec, playerctl previous"
        ", XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
      ];
    };
  };
}
