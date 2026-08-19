# hyprshell — pin to v4.10.8 until nixpkgs ships it.
#
# 4.10.7 (current nixpkgs) issues the window-focus dispatch *only* through
# hyprland-rs's `dispatch_new`, which routes through Hyprland's lua `eval`. That
# eval is rejected unless Hyprland runs the lua config manager — and we
# deliberately pin `configType = "hyprlang"` (see hyprland.nix). The result:
# the switcher/overview UI works but selecting a window silently fails with
# "eval is only supported with the lua config manager", so it can't switch apps.
#
# v4.10.8 added a legacy-syntax fallback (classic `FocusWindow` IPC dispatch)
# that works under hyprlang. This overlay self-removes once nixpkgs-unstable
# ships >= 4.10.8 — drop the file and the `services.hyprshell` build picks up
# upstream again.
_final: prev:
let
  version = "4.10.8";
  src = prev.fetchFromGitHub {
    owner = "H3rmt";
    repo = "hyprshell";
    tag = "v${version}";
    hash = "sha256-GXegc0W2xiRuSCjMpVc5mmKP5YFCYn87M/POTalISCA=";
  };
in
{
  hyprshell = prev.hyprshell.overrideAttrs (old: {
    inherit version src;
    cargoDeps = prev.rustPlatform.fetchCargoVendor {
      inherit src;
      inherit (old) pname;
      inherit version;
      hash = "sha256-idvY6AOLyx22Gy01kQyA4V8j0VupP5JNswsY4K5Oq9M=";
    };
  });
}
