# MangoHud performance overlay (FPS / frametime / CPU+GPU telemetry) for Linux
# desktop hosts. Import explicitly in a per-host HM import list — like
# hyprland.nix, it must NOT go in the shared linux/home-manager.nix (headless
# servers have no GPU overlay to draw).
#
# Session-wide: `enableSessionWide` exports MANGOHUD=1 so every Vulkan/OpenGL
# app picks the overlay up without a per-game `mangohud %command%` launch
# option. The base config starts HIDDEN (`no_display`) so it doesn't paint over
# the desktop — toggle it on per-game with Shift_L+F12, and cycle detail with
# the presets below (Shift_L+F10).
#
# Three presets ship via presets.conf: 1 = minimal (the default toggle-on view),
# 2 = balanced, 3 = telemetry (for hunting frametime stutter). F10 cycles 1→2→3
# (the `preset` list); preset 0 ("off") is excluded — F12 handles on/off.
#
# Layout is `legacy_layout = false` (fps on top, config-order rendering). Because
# parse_overlay_config parses the base config TWICE, display *elements* must live
# ONLY in presets.conf — an element in `settings` below renders twice. `settings`
# holds global/style settings only (safe to duplicate; they aren't elements).
#
# Colors are Stylix base16 (bare hex — MangoHud wants no leading '#'), so the
# overlay tracks myOptions.theme.scheme. No hardcoded hex (repo theming rule).
{ config, ... }:
let
  c = config.lib.stylix.colors;
  # green → yellow → red ramp for load/fps thresholds.
  ramp = [
    c.base0B
    c.base0A
    c.base08
  ];
in
{
  # The Vulkan layer is implicit and gated on MANGOHUD=1, and enableSessionWide
  # exports it to shells alone — without environment.d, anything the systemd user
  # manager launches (Steam from the graphical shell) loads no overlay at all.
  systemd.user.sessionVariables = {
    MANGOHUD = "1";
    MANGOHUD_DLSYM = "1";
  };

  programs.mangohud = {
    enable = true;
    enableSessionWide = true;

    settings = {
      # Hidden until toggled; flip these keys in-game.
      no_display = true;
      toggle_hud = "Shift_L+F12";
      toggle_preset = "Shift_L+F10";
      # Cycle only the visible presets. MangoHud's stock cycle is -1,0,1,2,3,4,
      # which includes -1 (base config — hidden here via no_display) and 0
      # (no_display), so F10 otherwise lands on "off" every few presses. On/off
      # is F12's job (toggle_hud); F10 just changes layout.
      preset = "1,2,3";

      # Ordered layout: elements render in the order each preset lists them
      # (fps first → fps on top), not the legacy fixed layout (fps at bottom).
      # Global on purpose — fps-on-top in every view. NB: display elements stay
      # in presets.conf only (see header) — none here, or they'd double up.
      legacy_layout = false;

      # Only the dGPU (NVIDIA = index 0); hide the AMD iGPU (shown as "GPU1",
      # unused for rendering).
      gpu_list = "0";

      # Layout / style (shared by every preset; not rendered elements).
      position = "top-left";
      font_size = 22;
      round_corners = 10;
      background_alpha = 0.5;

      # Theme (base16, bare hex).
      text_color = c.base05;
      background_color = c.base00;
      gpu_color = c.base0D;
      cpu_color = c.base0B;
      vram_color = c.base0E;
      ram_color = c.base0C;
      engine_color = c.base0E;
      frametime_color = c.base0A;
      gpu_load_color = ramp;
      cpu_load_color = ramp;
      fps_value = [
        30
        60
      ];
      fps_color = [
        c.base08
        c.base0A
        c.base0B
      ];
    };
  };

  # Live-cycleable presets (Shift_L+F10). These hold the display ELEMENTS, in
  # render order (fps first → on top). Global/style (position, font, theme,
  # legacy_layout, gpu_list) lives in MangoHud.conf above. Elements must NOT be
  # duplicated in the base config — it's parsed twice, so they'd render twice.
  xdg.configFile."MangoHud/presets.conf".text = ''
    [preset 0]
    no_display

    [preset 1]
    fps
    fps_metrics=avg,0.01

    [preset 2]
    fps
    fps_metrics=avg,0.01
    frame_timing=1
    cpu_stats
    cpu_temp
    cpu_load_change
    gpu_stats
    gpu_temp
    gpu_power
    gpu_load_change
    vram
    ram
    table_columns=3

    [preset 3]
    fps
    fps_metrics=avg,0.001,0.01
    frame_timing=1
    histogram
    cpu_stats
    cpu_temp
    cpu_power
    cpu_mhz
    core_load
    gpu_stats
    gpu_temp
    gpu_power
    gpu_core_clock
    gpu_mem_clock
    gpu_fan
    gpu_load_change
    throttling_status
    throttling_status_graph
    vram
    ram
    swap
    io_read
    io_write
    present_mode
    resolution
    gpu_name
    vulkan_driver
    table_columns=4
  '';
}
