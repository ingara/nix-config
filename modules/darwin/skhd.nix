# skhd.zig manages its own launchd agents via `skhd --install-service`:
#   - User agent (com.jackielii.skhd) via SMAppService
#   - skhd-grabber root daemon (for .remap tap-hold rules)
#   - Karabiner VHIDD daemon (DriverKit virtual keyboard)
#
# One-time setup: `skhd --install-service` (interactive — handles sudo,
# TCC prompts, grabber + dext installation).
#
# Config files + entrypoint: written here (this module owns skhd's whole
# concern). Selective per-WM .skhd links + the generated skhdrc that .loads only
# the enabled WMs' bundles — skhdrc is generated, so a whole-dir symlink would
# collide with it. Homebrew cask: homebrew.nix.
{ config, lib, ... }:
let
  user = config.myOptions.user.username;
  dots = import ../shared/home/lib/dotfiles.nix { inherit lib; };
in
{
  home-manager.sharedModules = [
    (
      { config, lib, ... }:
      let
        wm = config.myOptions.windowManager;
        # This sharedModule only exists on darwin (skhd is macOS-only), so the
        # isDarwin guard the central dotfiles.nix used is implicit here.
        anyWM = wm.enabled != [ ];
        src = relPath: dots.mkSource { inherit config relPath; };
      in
      {
        home.activation.restartSkhd = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          # `skhd --restart-service` (SMAppService) fails with SpawnFailed in
          # the activation context — kickstart the agent via launchd instead.
          /bin/launchctl kickstart -k "gui/$(id -u)/com.jackielii.skhd" || true
        '';

        xdg.configFile =
          lib.optionalAttrs anyWM {
            "skhd/common.skhd".source = src "skhd/common.skhd";
            "skhd/builtin-keyboard.skhd".source = src "skhd/builtin-keyboard.skhd";
            "skhd/skhdrc".text =
              lib.concatStringsSep "\n" (
                [
                  ''.load "builtin-keyboard.skhd"''
                  ''.load "common.skhd"''
                ]
                ++ lib.optional (lib.elem "yabai" wm.enabled) ''.load "yabai.skhd"''
                ++ lib.optional (lib.elem "omniwm" wm.enabled) ''.load "omniwm.skhd"''
                ++ lib.optional (lib.elem "nehir" wm.enabled) ''.load "nehir.skhd"''
              )
              + "\n";
          }
          // lib.optionalAttrs (lib.elem "yabai" wm.enabled) {
            "skhd/yabai.skhd".source = src "skhd/yabai.skhd";
          }
          // lib.optionalAttrs (lib.elem "omniwm" wm.enabled) {
            "skhd/omniwm.skhd".source = src "skhd/omniwm.skhd";
          }
          // lib.optionalAttrs (lib.elem "nehir" wm.enabled) {
            "skhd/nehir.skhd".source = src "skhd/nehir.skhd";
          };
      }
    )
  ];

  # Auto-heal watchdog for the grabber/VHIDD wedge (see issue #21 and the
  # "Internal keyboard + trackpad clicks dead" runbook in the private repo):
  # input can die while recovery needs root — and the operator can't type a
  # sudo password on a dead keyboard. Two trigger paths:
  #
  # 1. AUTO: state-based wedge detection — grabber alive + no
  #    VirtualHIDKeyboard in `hidutil list`. Catches the signatures where the
  #    virtual device vanishes (wedges #1/#2). NOT log-based: the incidents
  #    logged differently and the VHIDD log rotates. A grabber that is simply
  #    dead is NOT a wedge (process death releases the seize; the keyboard
  #    works unremapped). Two consecutive 30s samples confirm before acting;
  #    a 10-min cooldown stops a genuinely broken chain from becoming a
  #    kickstart loop. Worst-case false positive = one ~2s input
  #    interruption, same as the manual recovery.
  #
  # 2. MANUAL: `touch /Users/Shared/skhd-kick` (world-writable path — works
  #    from any session, agent, or Finder without sudo). Covers wedge #3
  #    (2026-06-12), where every observable state was healthy (device
  #    present, VHIDD ready, no secure input) yet events didn't flow — there
  #    is no pollable signal for that, but a human noticing a dead keyboard
  #    is detection enough; this gives them a root-less lever.
  launchd.daemons.skhd-wedge-watchdog = {
    script = ''
      state_dir=/var/db/skhd-watchdog
      /bin/mkdir -p "$state_dir"
      kick_file=/Users/Shared/skhd-kick

      kick_chain() {
        echo "$(/bin/date '+%F %T') $1 — kickstarting chain"
        /bin/launchctl kickstart -k system/org.pqrs.service.daemon.Karabiner-VirtualHIDDevice-Daemon || true
        /bin/sleep 2
        /bin/launchctl kickstart -k system/com.jackielii.skhd.grabber || true
        /bin/date +%s >"$state_dir/last-kick"
        /bin/rm -f "$state_dir/suspect"
        # User-domain pieces: hotkey agent restart + a heads-up notification
        # so the recovery isn't silent.
        uid=$(/usr/bin/id -u ${user} 2>/dev/null) || return 0
        /bin/launchctl kickstart -k "gui/$uid/com.jackielii.skhd" || true
        /bin/launchctl asuser "$uid" /usr/bin/osascript \
          -e "display notification \"$1 — input chain kickstarted\" with title \"skhd watchdog\"" || true
      }

      # Manual trigger: deliberate, so no sampling and no cooldown. Remove
      # the marker BEFORE acting so a failed kick can't loop.
      if [ -e "$kick_file" ]; then
        /bin/rm -f "$kick_file"
        kick_chain "manual trigger ($kick_file)"
        exit 0
      fi

      # Healthy (or grabber not running at all) → clear suspicion, done.
      if ! /usr/bin/pgrep -xq skhd-grabber; then
        /bin/rm -f "$state_dir/suspect"
        exit 0
      fi
      if /usr/bin/hidutil list 2>/dev/null | /usr/bin/grep -q "VirtualHIDKeyboard"; then
        /bin/rm -f "$state_dir/suspect"
        exit 0
      fi

      # Wedge condition seen. First sighting only marks; act on the second.
      if [ ! -f "$state_dir/suspect" ]; then
        /usr/bin/touch "$state_dir/suspect"
        exit 0
      fi

      now=$(/bin/date +%s)
      last=$(/bin/cat "$state_dir/last-kick" 2>/dev/null || echo 0)
      if [ $((now - last)) -lt 600 ]; then
        exit 0
      fi

      kick_chain "wedge confirmed (grabber alive, VirtualHIDKeyboard absent)"
    '';
    serviceConfig = {
      StartInterval = 30;
      StandardOutPath = "/var/log/skhd-watchdog.log";
      StandardErrorPath = "/var/log/skhd-watchdog.log";
    };
  };
}
