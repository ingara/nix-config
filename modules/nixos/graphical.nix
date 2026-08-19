# WM-agnostic GUI substrate for NixOS graphical hosts (the `graphical` tag):
# audio, the freedesktop secrets service, portals, greetd, and the compositor
# enable-blocks gated on windowManager.enabled set membership. A host supplies
# its own greetd session, GPU pins, and keyboard layout on top.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  wm = config.myOptions.windowManager;
in
{
  # greetd enabled by default; the consuming host supplies its session settings.
  # mkDefault so a recovery specialisation's `lib.mkForce false` can win and
  # land at a plain getty (force-disabling the graphical login path).
  services.greetd.enable = lib.mkDefault true;

  # programs.hyprland wires the session desktop entry, XWayland, and xdph;
  # withUWSM scopes exec-once units under the systemd graphical session.
  programs.hyprland = lib.mkIf (lib.elem "hyprland" wm.enabled) {
    enable = true;
    withUWSM = true;
  };

  # withUWSM only enables the uwsm binary; the compositor desktop entry is
  # separate. sw/bin path keeps UWSM and the installed Hyprland version-matched.
  programs.uwsm.waylandCompositors.hyprland = lib.mkIf (lib.elem "hyprland" wm.enabled) {
    prettyName = "Hyprland";
    comment = "Hyprland compositor managed by UWSM";
    binPath = "/run/current-system/sw/bin/Hyprland";
  };

  # programs.niri registers the session (niri.desktop → niri-session), wires the
  # gnome+gtk portals with a per-session `xdg.portal.config.niri`, and guards the
  # user unit against restart-on-switch. useNautilus = false pins the niri
  # session's FileChooser to gtk (the multi-compositor portal pin, issue #45)
  # and keeps Nautilus out of the closure. Deliberately NO uwsm entry: niri's
  # own `niri-session` already provides the systemd session management
  # (niri.service → graphical-session.target); wrapping it in UWSM would run
  # two competing session managers.
  programs.niri = lib.mkIf (lib.elem "niri" wm.enabled) {
    enable = true;
    useNautilus = false;
  };

  # X11 clients under niri (Steam, games): niri has no built-in XWayland — it
  # auto-spawns xwayland-satellite from PATH on the first X11 connection
  # (built-in integration since niri 25.08; the binary just has to exist).
  environment.systemPackages = lib.mkIf (lib.elem "niri" wm.enabled) [ pkgs.xwayland-satellite ];

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    # 32-bit ALSA support is required by Proton; Wine titles open ALSA devices
    # directly even on a PipeWire system.
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # gnome-keyring provides the freedesktop Secret Service (org.freedesktop.secrets).
  # PAM wiring: the greetd NixOS module auto-sets
  # security.pam.services.greetd.enableGnomeKeyring when this is true.
  services.gnome.gnome-keyring.enable = true;

  # ...but disable gnome-keyring's SSH agent (gcr-ssh-agent). Its socket unit
  # points the session's SSH_AUTH_SOCK at gcr's EMPTY agent, which breaks
  # op-ssh-sign (commit signing) — the 1Password agent is wanted instead. This
  # defaults to gnome-keyring.enable; turning it off removes the gcr units. The
  # Secret Service daemon above is independent and unaffected.
  services.gnome.gcr-ssh-agent.enable = false;

  # xdg-desktop-portal-hyprland (xdph) is added automatically by
  # programs.hyprland. gtk is required for file-picker dialogs (xdph doesn't
  # cover them), so add it explicitly.
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  # Explicit per-session portal pin for the Hyprland session (issue #45): with a
  # second compositor enabled, xdg-desktop-portal-gnome joins the installed
  # portal set and also implements FileChooser/Screenshot — which impl serves a
  # session is a RUNTIME resolution (nixpkgs#372034), invisible to drv-check.
  # This /etc entry shadows the hyprland package's own portals.conf (an
  # `xdg.portal.config.<desktop>` entry is preferred over `configPackages`) and
  # pins the file chooser to gtk deterministically. Overriding a listOf entry
  # with mkForce can't remove compositor-contributed portals — pin per-desktop
  # instead. The niri session's equivalent pin comes from programs.niri above.
  xdg.portal.config.hyprland = lib.mkIf (lib.elem "hyprland" wm.enabled) {
    default = [
      "hyprland"
      "gtk"
    ];
    "org.freedesktop.impl.portal.FileChooser" = "gtk";
  };
}
