# skhd.zig manages its own launchd agents via `skhd --install-service`:
#   - User agent (com.jackielii.skhd) via SMAppService
#   - skhd-grabber root daemon (for .remap tap-hold rules)
#   - Karabiner VHIDD daemon (DriverKit virtual keyboard)
#
# One-time setup: `skhd --install-service` (interactive — handles sudo,
# TCC prompts, grabber + dext installation).
#
# Config files + entrypoint: written here (this module owns skhd's whole
# concern). The Nehir/OmniWM pair has one runtime-selected include, written by
# wm-switch; generic WM loading remains unchanged. Homebrew cask: homebrew.nix.
{ lib, ... }:
let
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
        runOne = lib.elem wm.default [
          "nehir"
          "omniwm"
        ];
      in
      {
        home.activation.restartSkhd = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          ${lib.optionalString runOne ''
            # Keep this atomic and under wm-switch's lock: a concurrent switch
            # must not turn the placeholder write into a write through its
            # mutable-dotfile symlink.
            /bin/mkdir -p "$HOME/.local/state"
            /usr/bin/lockf -t 120 "$HOME/.local/state/wm-switch.lock" /bin/sh -c '
              layer="$HOME/.config/skhd/active-wm.skhd"
              if [ ! -e "$layer" ]; then
                tmp=$(/usr/bin/mktemp "$HOME/.config/skhd/.active-wm.XXXXXXXX") || exit 1
                /usr/bin/printf "%s\n" "# no active WM-specific bindings" > "$tmp" || exit 1
                /bin/mv -f "$tmp" "$layer"
              fi
            ' || exit 1
          ''}
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
                ++ lib.optional runOne ''.load "active-wm.skhd"''
              )
              + "\n";
          }
          // lib.optionalAttrs (lib.elem "yabai" wm.enabled) {
            "skhd/yabai.skhd".source = src "skhd/yabai.skhd";
          }
          // lib.optionalAttrs (lib.elem "omniwm" wm.enabled) {
            "skhd/omniwm.skhd".source = src "skhd/omniwm.skhd";
            "skhd/omniwm-ratio.sh".source = src "skhd/omniwm-ratio.sh";
          }
          // lib.optionalAttrs (lib.elem "nehir" wm.enabled) {
            "skhd/nehir.skhd".source = src "skhd/nehir.skhd";
            "skhd/nehir-ratio.sh".source = src "skhd/nehir-ratio.sh";
          };
      }
    )
  ];
}
