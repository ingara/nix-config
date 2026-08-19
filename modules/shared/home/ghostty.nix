# Ghostty — config + theme via programs.ghostty. The binary comes from nixpkgs
# ONLY on NixOS (where nix GUI apps work); on darwin it's a homebrew cask
# (homebrew.nix) and on generic Linux it is supplied externally — both signalled by
# package = null, which renders config + theme but installs nothing. nixpkgs
# ghostty is Linux-only and unreliable on foreign distros, so this split is
# load-bearing, not cosmetic.
#
# Theme (palette, font, opacity) comes from Stylix's ghostty target, driven by
# the globals in stylix-base.nix; this module owns only behaviour (keybinds,
# shell integration, quick terminal) and the package split.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.myOptions) hasGui;
in
{
  programs.ghostty = {
    enable = hasGui;

    package =
      if pkgs.stdenv.hostPlatform.isDarwin then
        null # binary: homebrew cask (homebrew.nix)
      else if config.targets.genericLinux.enable then
        null # binary: externally supplied (nixpkgs GUI apps unreliable off NixOS)
      else
        pkgs.ghostty; # NixOS

    # systemd integration asserts against package = null; we don't need it.
    systemd.enable = false;

    # Ghostty auto-injects shell integration itself (driven by
    # shell-integration-features below); HM's manual `source …` would be a
    # redundant second path, so keep it off — matches the prior dotfile setup.
    enableFishIntegration = false;
    enableBashIntegration = false;
    enableZshIntegration = false;

    # installBatSyntax (bat highlighting for ghostty's config) is left at its
    # default: it auto-enables where the package is present (NixOS) and auto-
    # disables where package = null (darwin/generic Linux, where it would assert).

    settings = {
      # Stylix's ghostty target scales fonts.sizes.terminal by 4/3 on darwin,
      # but its wezterm target passes the same value unscaled — counter the
      # scaling so both terminals share one numeric size.
      font-size = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
        lib.mkForce config.stylix.fonts.sizes.terminal
      );

      # Blinking cursor forces a continuous 120 Hz render loop on ProMotion
      # displays (even idle), which pins WindowServer recompositing the
      # translucent background every frame. Disabling it cuts ghostty idle
      # CPU ~85%. Upstream-unfixed as of 1.3.1:
      # https://github.com/ghostty-org/ghostty/discussions/10397
      cursor-style-blink = false;

      # macOS-style selection: drag selects but doesn't auto-copy; Cmd+C copies.
      # The Cmd+C-with-no-selection fall-through into Meta+C is silenced fish-side
      # (fish.nix fish_user_key_bindings).
      copy-on-select = false;

      quick-terminal-space-behavior = "move";
      shell-integration-features = "no-cursor,sudo,ssh-terminfo,ssh-env";

      keybind = [
        "global:cmd+ctrl+t=toggle_quick_terminal"

        # Ctrl+digit CSI u shim. Ghostty 1.3.1's modifyOtherKeys mode 2 doesn't
        # disambiguate Ctrl+digit (verified empirically), so tmux can't bind
        # C-1..9. Emit the CSI u (libtickit) sequences ourselves — tmux accepts
        # them with extended-keys on (tmux.nix). Apps that don't understand CSI u
        # ignore them, so this is harmless outside tmux. Revisit once Ghostty's
        # modifyOtherKeys mode 2 covers digits (upstream-watch item).
        "ctrl+1=csi:49;5u"
        "ctrl+2=csi:50;5u"
        "ctrl+3=csi:51;5u"
        "ctrl+4=csi:52;5u"
        "ctrl+5=csi:53;5u"
        "ctrl+6=csi:54;5u"
        "ctrl+7=csi:55;5u"
        "ctrl+8=csi:56;5u"
        "ctrl+9=csi:57;5u"
      ];
    };
  };
}
