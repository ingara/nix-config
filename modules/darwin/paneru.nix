# Paneru scrolling WM — Home Manager wiring.
#
# Paneru is a per-user launchd agent; the homeModules.paneru module handles
# service management and config generation. Settings are declared here as
# Nix attrsets (rendered to TOML via services.paneru.settings) so no
# separate dotfile symlink is needed.
#
# This module is a no-op unless `"paneru"` is in `myOptions.windowManager.enabled`.
#
# Build cost: Paneru ships no prebuilt binary (checked v0.4.3) — GitHub releases
# carry no assets, the Homebrew formula compiles via cargo, and there's no
# Cachix. So this builds from source; the heavy dep is `wgpu`. One-time per
# version (cached in /nix/store afterward), but recompiles on input bumps / new
# machines. If upstream starts publishing a binary or a cache, point
# services.paneru.package at it (or push our build to a Cachix the hosts share).
{ config, lib, ... }:

let
  cfg = config.myOptions.windowManager;

  # Switch to / send the focused window to virtual workspaces 1–9.
  # Send-and-stay (virtualsendnum) keeps focus on the current workspace.
  # Digits resolve via the current keyboard layout (norwerty-safe).
  workspaceBindings = builtins.listToAttrs (
    lib.concatMap (n: [
      {
        name = "window_virtualnum_${toString n}";
        value = "alt - ${toString n}";
      }
      {
        name = "window_virtualsendnum_${toString n}";
        value = "alt + shift - ${toString n}";
      }
    ]) (lib.range 1 9)
  );
in
{
  services.paneru = {
    # paneru's upstream homeModule auto-starts (RunAtLoad) whenever enabled, so
    # in a multi-WM setup it would run at login even when it isn't `default`.
    # Reconciling that (a runtime evictor for non-default agents) is part of the
    # run-one mechanics still to land (design §3.3 / tasks.md 2.3). Today only
    # single-WM hosts exist, so `enabled` membership == active and this is dormant.
    enable = lib.elem "paneru" cfg.enabled;
    settings = {
      options = {
        # Keyboard-driven niri workflow: no mouse-follows / focus-follows.
        focus_follows_mouse = false;
        mouse_follows_focus = false;
        # Keep native macOS tab grouping (e.g. Ghostty) — do not auto-merge
        # windows into tabs. Load-bearing: this is why Paneru was chosen.
        disable_native_tabs = false;
        preset_column_widths = [
          0.25
          0.33
          0.5
          0.66
          0.75
        ];
        animation_speed = 12.0;
      };

      padding = {
        top = 6;
        bottom = 6;
        left = 6;
        right = 6;
      };

      # Focus highlight via Paneru's own (sliver-aware) border — jankyborders
      # is disabled for paneru in bar.nix, so this is its replacement. Color
      # from Stylix; width matches the former jankyborders width.
      decorations.active.border = {
        enabled = true;
        color = config.lib.stylix.colors.withHashtag.base0D;
        width = 3.0;
      };

      # Binding scheme follows docs/keybindings.md: alt = focus/primary,
      # alt+shift = move the window, ctrl+alt = workspace-nav + global/
      # destructive. Punctuation uses Paneru's word key-names (comma/period/
      # minus/equal): the binding parser splits the string on `-`, so a literal
      # `-`/`,` would break it; the names map to fixed keycodes (src/config.rs
      # virtual_keycode table), norwerty-safe.
      bindings = {
        # Focus
        window_focus_west = "alt - h";
        window_focus_south = "alt - j";
        window_focus_north = "alt - k";
        window_focus_east = "alt - l";
        window_focus_first = "alt - u";
        window_focus_last = "alt - o";

        # Move / swap window
        window_swap_west = "alt + shift - h";
        window_swap_south = "alt + shift - j";
        window_swap_north = "alt + shift - k";
        window_swap_east = "alt + shift - l";
        window_swap_first = "alt + shift - u";
        window_swap_last = "alt + shift - o";

        # Column width / layout. Resize rides minus/equal (off the ctrl+alt
        # tier); alt-r still cycles width presets. Paneru has no height-resize
        # and no true-fullscreen op (src/config.rs Operation enum), so the
        # convention's Shift+-/= height and `f` fullscreen stay unbound here.
        window_resize = "alt - r";
        window_shrink = "alt - minus";
        window_grow = "alt - equal";
        window_fullwidth = "alt - w";
        window_center = "alt - c";
        window_equalize = "alt - b";

        # Stack/unstack ≈ consume/expel into column → comma/period per the
        # convention (word key-names, see scheme note above).
        window_stack = "alt - comma";
        window_unstack = "alt - period";

        # Float + multi-display
        window_togglefloatlayer = "alt - g";
        window_nextdisplay = "alt - m";
        window_nextdisplaysend = "alt + shift - m";

        # Adjacent workspace nav + move-window-to-adjacent
        window_virtual_south = "ctrl + alt - j";
        window_virtual_north = "ctrl + alt - k";
        window_virtualmove_south = "ctrl + alt + shift - j";
        window_virtualmove_north = "ctrl + alt + shift - k";

        # Global
        window_manage = "ctrl + alt - t"; # toggle managed state of focused window
        quit = "ctrl + alt - q";
      }
      // workspaceBindings;
    };
  };
}
