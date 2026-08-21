# Nehir scrolling WM — Home Manager config generation.
#
# Nehir is a niri-style (column-scrolling) macOS WM, an opinionated fork of
# OmniWM. Unlike Paneru it ships no Nix module: it's a Homebrew cask
# (guria/tap/nehir, wired in window-manager.nix) that reads split TOML config
# from ~/.config/nehir/. This module Nix-generates those config files and
# symlinks them via xdg.configFile.
#
# This module is a no-op unless `"nehir"` is in `myOptions.windowManager.enabled`.
#
# What we manage vs. what Nehir owns at runtime:
#   - settings.toml, hotkeys.toml, workspaces.toml,
#     monitors.d/{lg-ultrafine,odyssey-g8}.toml  -> Nix-generated here
#     (read-only store symlinks). Declarative source of truth; runtime GUI
#     toggles of these won't persist back (by design). Nehir live-reloads them
#     on change and, after its one-time onboarding write, respects the external
#     symlinks.
#   - apprules.d/, other monitors.d/ files -> left to Nehir. It creates and
#     owns these at runtime; we only pin the external monitors we tune.
{ config, lib, ... }:

let
  cfg = config.myOptions.windowManager;

  colors = config.lib.stylix.colors;
  # Stylix exposes `baseXX-rgb-{r,g,b}` as 0–255 *strings*; Nehir's border
  # color wants RGBA floats in 0.0–1.0. Convert to a real Nix float (a
  # whole-number float would lose its `.0` through TOML generation, so we
  # hand-write the file and interpolate the channel values).
  chan = c: toString ((lib.toInt colors."base0D-rgb-${c}") / 255.0);

  # Core settings. The Stylix focus border replaces jankyborders, which is
  # disabled for nehir in bar.nix — re-enabling it there would double-draw.
  settingsToml = ''
    # Nehir core settings — Nix-generated (modules/darwin/nehir.nix).
    [general]
    hotkeysEnabled = true
    # IPC socket (~/Library/Caches/dev.guria.nehir/ipc.sock) for `nehirctl
    # query`/`command`/`subscribe` — scripting, state inspection, debugging.
    ipcEnabled = true

    [focus]
    followsMouse = false
    moveMouseToFocusedWindow = false

    [gaps]
    size = 6.0

    [gaps.outer]
    left = 6.0
    right = 6.0
    top = 6.0
    bottom = 6.0

    [niri]
    columnWidthPresets = [0.25, 0.33, 0.5, 0.66, 0.75]

    [borders]
    enabled = true
    width = 3.0

    [borders.color]
    red = ${chan "r"}
    green = ${chan "g"}
    blue = ${chan "b"}
    alpha = 1.0

    [workspaceBar]
    enabled = true
  '';

  # Keybinds follow the cross-platform convention (docs/keybindings.md): Option =
  # focus/primary, Option+Shift = move the window, Control+Option = workspace nav.
  # Resize rides Option+-/= (width) and Option+Shift+-/= (height); consume/expel
  # ride Option+,/. — all Norwerty-safe (these are not the å/´/ø/æ symbol keys
  # nor the é/grave dead keys, and Nehir resolves key *names* like Minus/Comma to
  # physical keycodes, layout-independent). Action ids + key-name tokens verified
  # against the installed Nehir 0.5.1 binary (HotkeysTOMLCodec / nehirctl
  # capabilities). `{N}` expands to digits 1–9.
  #
  # Gaps vs the convention (no Nehir action): center/fit column; move-window-to-
  # monitor (monitorNext/Previous are focus-only — cross-monitor moves route via
  # workspace-on-monitor); window-level back-and-forth. The Option+R ratio
  # splits live in skhd (nehir.skhd → nehir-ratio.sh) — hotkeys.toml has no
  # parameterized set-column-width action.
  hotkeysToml = ''
    # Nehir keybindings — Nix-generated (modules/darwin/nehir.nix).
    [workspace]
    switch = "Option+{N}"
    moveTo = "Option+Shift+{N}"
    next = "Control+Option+J"
    previous = "Control+Option+K"

    [focus]
    left = "Option+H"
    down = "Option+J"
    up = "Option+K"
    right = "Option+L"
    columnFirst = "Option+U"
    columnLast = "Option+O"
    monitorNext = "Option+M"
    monitorPrevious = "Option+N"

    [move]
    left = "Option+Shift+H"
    down = "Option+Shift+J"
    up = "Option+Shift+K"
    right = "Option+Shift+L"
    columnToFirst = "Option+Shift+U"
    columnToLast = "Option+Shift+O"
    windowToWorkspaceDown = "Control+Option+Shift+J"
    windowToWorkspaceUp = "Control+Option+Shift+K"
    consumeIntoColumn = "Option+Comma"
    expelFromColumn = "Option+Period"

    [layout]
    decreaseColumnWidth = "Option+Minus"
    increaseColumnWidth = "Option+Equal"
    decreaseWindowHeight = "Option+Shift+Minus"
    increaseWindowHeight = "Option+Shift+Equal"
    toggleFullscreen = "Option+F"
    toggleColumnFullWidth = "Option+W"
    balanceSizes = "Option+B"
    toggleColumnTabbed = "Option+T"
    toggleFocusedFloating = "Option+G"

    [ui]
    toggleOverview = "Option+Tab"
  '';

  # Workspace -> monitor role assignment. 1–3 on the primary (macOS main)
  # display, 4–5 on the secondary. Roles (not "specific" + monitorName) keep
  # this layout-position based and free of hardcoded display names.
  #
  # Caveat: Nehir's restore path resolves `secondary` to nil when only one
  # display is connected (no fallback to main, unlike `main` itself), so in
  # clamshell 4–5 may be unreachable rather than collapsing onto the single
  # display. Whether the live dock/undock path reflows them is unverified —
  # under evaluation. If they strand, a display-change watcher that swaps this
  # file between a docked/clamshell variant is the fix.
  workspacesToml = ''
    # Nehir workspaces — Nix-generated (modules/darwin/nehir.nix).
    [1]
    monitor = "main"

    [2]
    monitor = "main"

    [3]
    monitor = "main"

    [4]
    monitor = "secondary"

    [5]
    monitor = "secondary"
  '';

  # Per-monitor override for the external LG UltraFine (the macOS main display
  # in the docked setup). Matched by name only — `displayId` is runtime-volatile
  # so we leave it for Nehir to resolve. Top padding clears the SketchyBar
  # menu-bar overlay; the bar yOffset nudges Nehir's own per-monitor workspace
  # bar down so the two don't collide. Integer values match Nehir's own writer.
  monitorsLgUltrafineToml = ''
    # Nehir monitor override (external LG UltraFine) — Nix-generated.
    [match]
    name = "LG ULTRAFINE"

    [gaps]
    outerTop = 36

    [bar]
    yOffset = 12
  '';

  # Same tuning as the LG UltraFine above, for the Samsung Odyssey G8.
  monitorsOdysseyG8Toml = ''
    # Nehir monitor override (external Samsung Odyssey G8) — Nix-generated.
    [match]
    name = "Odyssey G8"

    [gaps]
    outerTop = 36

    [bar]
    yOffset = 12
  '';
in
{
  xdg.configFile = lib.mkIf (lib.elem "nehir" cfg.enabled) {
    "nehir/settings.toml".text = settingsToml;
    "nehir/hotkeys.toml".text = hotkeysToml;
    "nehir/workspaces.toml".text = workspacesToml;
    "nehir/monitors.d/lg-ultrafine.toml".text = monitorsLgUltrafineToml;
    "nehir/monitors.d/odyssey-g8.toml".text = monitorsOdysseyG8Toml;
  };
}
