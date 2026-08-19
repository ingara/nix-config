# WM-agnostic desktop-session plumbing shared by the Linux WM bundles
# (hyprland.nix / niri.nix): launcher fallback, polkit agent, cursor theme,
# cross-WM Stylix targets, media-key helper, and the shared screenshot dir.
# One module so these can't drift between the per-WM bundles and every piece
# survives a host dropping either WM from `enabled`.
#
# Gated on ANY WM in `myOptions.windowManager.enabled`. Import alongside the
# WM modules (the graphical role's home slot); do NOT add it to the shared
# linux/home-manager.nix — that module is also used by headless servers.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  wm = config.myOptions.windowManager;
in
lib.mkIf (wm.enabled != [ ]) {
  # playerctl backs both WMs' media-key binds (the browser's MPRIS player);
  # wpctl for volume comes from the system wireplumber service (on PATH).
  home.packages = [ pkgs.playerctl ];

  # nixpkgs' Electron/Chromium wrappers gate their Wayland switches on this
  # var. Electron ≥ 39 auto-detects Wayland unaided, so only apps bundling an
  # older Electron need it — but for those the fallback is an XWayland client,
  # which has no fractional-scale protocol: the compositor renders it at 1x and
  # upscales, visibly blurry on any output at non-integer scale.
  #   - home.sessionVariables → hm-session-vars.sh: interactive shells.
  #   - systemd.user.sessionVariables → environment.d: the GUI apps a UWSM
  #     graphical session launches outside a shell. A compositor-level `env`
  #     reaches only the compositor's own children, so it misses these.
  home.sessionVariables.NIXOS_OZONE_WL = "1";
  systemd.user.sessionVariables.NIXOS_OZONE_WL = "1";

  # Ensure the shared screenshot target exists (satty's save path under
  # Hyprland, screenshot-path under niri) so saving never fails on a missing
  # dir. .keep is the conventional placeholder for an otherwise-empty tracked
  # directory.
  home.file."Pictures/Screenshots/.keep".text = "";

  # fuzzel is the launcher fallback. Not dotfile-managed, so the HM module +
  # its Stylix target are the clean path (installs fuzzel and themes it). A
  # per-host desktop shell overrides each WM's launcher bind; fuzzel stays
  # installed as the shell-independent fallback.
  programs.fuzzel.enable = true;

  # Polkit agent — required for privilege prompts (e.g. 1Password's
  # op-ssh-sign and any pkexec dialog). A standalone Qt agent on
  # graphical-session.target, not Hyprland-coupled despite the name — serves
  # whichever session is active.
  services.hyprpolkitagent.enable = true;

  # Cross-WM Stylix targets. NixOS HM hosts set `stylix.autoEnable = false`
  # (easy-hosts-presets.nix), so each target must be enabled explicitly —
  # cross-platform targets in shared/home/stylix-base.nix, desktop-wide ones
  # here, compositor-specific ones in each WM module.
  stylix.targets.fuzzel.enable = true;
  # GTK theming — so GTK apps and, importantly, the xdg-desktop-portal-gtk file
  # chooser (the portal dialog every app's "open file" routes through) follow
  # the Stylix palette instead of falling back to default light Adwaita.
  stylix.targets.gtk.enable = true;
  # Qt apps (pavucontrol, 1Password GUI — #41); qt5ct/kvantum come from the
  # target itself.
  stylix.targets.qt.enable = true;

  # Cursor theme — Rosé Pine (BreezeX). A fixed aesthetic choice, independent
  # of the base16 scheme (rose-pine-cursor ships only the dark/Dawn pair, not a
  # per-scheme set). Stylix's cursor option wires home.pointerCursor with
  # x11.enable + gtk.enable, so XCURSOR_THEME/SIZE (read by both compositors
  # and XWayland) and the GTK cursor all resolve the same theme. niri.nix
  # additionally mirrors it into niri's own cursor block. Size 28 matches this
  # machine's shared 4K display.
  stylix.cursor = {
    package = pkgs.rose-pine-cursor;
    name = "BreezeX-RosePine-Linux";
    size = 28;
  };
  # home-manager wants cursor generation enabled explicitly rather than inferred
  # from the presence of settings; stylix.cursor sets the theme but not this flag.
  home.pointerCursor.enable = true;
}
