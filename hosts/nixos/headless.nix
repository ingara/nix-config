# System config for the headless servers, on top of the generic base.nix,
# pulled in via the `server` tag. Downstream configs may merge more into the
# same tag.
{ config, lib, ... }:

{
  # Tailscale SSH owns both the listener and tunnel, so downstream users need
  # an independently proven transport before allowing activation restarts.
  systemd.services.tailscaled.restartIfChanged = false;

  # networkd owns the interface config under the deploy path, so keep it from
  # disrupting the tunnel during activation.
  systemd.services.systemd-networkd.restartIfChanged = false;

  # A failed mount or fsck at boot must not drop into an emergency shell: on
  # a remote host that shell is a lockout (console-only, wants a root
  # password). Keep booting so the network and SSH come up.
  systemd.enableEmergencyMode = false;

  # A slow DHCP lease must not stall boot or a switch waiting for "online".
  systemd.network.wait-online.enable = false;

  # Restart networkd/resolved in place on switch instead of stop → start,
  # keeping the network gap during activation minimal.
  systemd.services.systemd-networkd.stopIfChanged = false;
  systemd.services.systemd-resolved.stopIfChanged = false;

  boot.tmp.cleanOnBoot = true;

  # Pure flakes: no channel state or nix-channel on PATH, and
  # command-not-found depends on a channel-provided database absent here.
  nix.channel.enable = false;
  programs.command-not-found.enable = false;

  nix.settings = {
    # Free store space before a build fills the small cloud disk.
    min-free = 512 * 1024 * 1024;
    max-free = 3 * 1024 * 1024 * 1024;
    log-lines = 25;
    # Fall back to source builds quickly when a cache is unreachable.
    connect-timeout = 5;
    fallback = true;
  };

  # Only nix-declared keys count — a runtime-written ~/.ssh/authorized_keys
  # cannot grant persistence. Tailscale SSH bypasses authorized_keys, so the
  # tailnet login path is unaffected.
  services.openssh.authorizedKeysFiles = lib.mkForce [ "/etc/ssh/authorized_keys.d/%u" ];

  # Servers fetch from GitHub; pin its host key instead of trusting first use.
  programs.ssh.knownHosts.github = {
    hostNames = [ "github.com" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
  };

  # Non-wheel users cannot exec sudo at all.
  security.sudo.execWheelOnly = true;
  # The lecture flag is per-user mutable state under /var.
  security.sudo.extraConfig = ''
    Defaults lecture = never
  '';

  # Timers keyed to UTC don't double-fire or skip on DST transitions, and
  # cross-host log correlation needs no offset math. (Workstations keep the
  # local zone from base.nix.)
  time.timeZone = lib.mkForce "UTC";

  # No GUI exists to consume these.
  fonts.fontconfig.enable = false;
  xdg.autostart.enable = false;
  xdg.icons.enable = false;
  xdg.menus.enable = false;
  xdg.mime.enable = false;
  xdg.sounds.enable = false;

  # Servers never suspend.
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
  };

  # Under memory pressure, prefer killing a build over a running service.
  systemd.services.nix-daemon.serviceConfig.OOMScoreAdjust = 250;

  # WAN port 22 is closed, so refused-connection logs are pure scanner noise.
  networking.firewall.logRefusedConnections = false;

  # LLMNR answers link-local name queries — a poisoning surface with no use
  # on a cloud VM.
  services.resolved.settings.Resolve.LLMNR = "false";

  # Anything trying to open a browser prints the URL instead.
  environment.variables.BROWSER = "echo";

  # Abort activation when the closure's hostname differs from the running
  # host's — the wrong-target guard for push deploys. Deliberately
  # non-interactive: under deploy-rs stdin is closed, so a mismatch fails the
  # check and magic-rollback reverts. EXPECTED_HOSTNAME=<name> overrides for
  # an intentional rename. (Skipped on fresh installs: no /run/booted-system.)
  system.preSwitchChecks.detectHostnameChange = ''
    detectHostnameChange() {
      local actual desired
      actual="$(< /proc/sys/kernel/hostname)"
      desired="${config.networking.hostName}"
      if [[ ! -e /run/booted-system || "$actual" == "nixos-installer" ]]; then
        return
      fi
      if [[ "$actual" == "$desired" || "''${EXPECTED_HOSTNAME:-}" == "$desired" ]]; then
        return
      fi
      echo "ERROR: closure is for host '$desired' but this machine is '$actual'." >&2
      echo "Wrong deploy target? Set EXPECTED_HOSTNAME=$desired to override." >&2
      exit 1
    }
    detectHostnameChange
  '';
}
