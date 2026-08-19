# Shared HM Stylix core. Each platform HM entry point (darwin, the NixOS
# preset and standalone Linux configurations) imports this and layers only its own
# platform-specific `targets` extras.
#
# Every `stylix.fonts.*` slot is set explicitly: an unset slot silently
# inherits an upstream default font (and its build closure) nobody chose —
# the unset emoji default once broke a darwin switch when the binary cache
# lagged and noto pulled an afdko from-source build (#48).
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
  stylix = {
    enable = true;
    # Stylix and home-manager both track master, so their release strings
    # never match and the version check is a permanent false positive. It
    # gates a warning only, not behaviour; a real incompatibility still
    # errors.
    enableReleaseChecks = false;
    base16Scheme = config.lib.myTheme.schemeYaml;
    # Rosé Pine's dark ports fill base07 (the spec's "lightest" slot) with a
    # dark overlay tone, so everything mapped to bright white — terminal ANSI
    # color 15, starship's bright-white, bat foregrounds — renders dark-on-dark.
    # Restore the palette's light text tint. (Palette-definition site: a hex
    # literal is correct here, same as the scheme yaml itself.)
    override =
      lib.optionalAttrs
        (builtins.elem config.lib.myTheme.scheme [
          "rose-pine"
          "rose-pine-moon"
        ])
        {
          base07 = "e0def4";
        };
    polarity = config.lib.myTheme.polarity;

    fonts = {
      monospace = {
        package = pkgs.callPackage ./fonts/pragmasevka.nix { };
        name = "Pragmasevka Nerd Font";
      };
      # Explicit DejaVu: a deliberate choice rather than an inherited default;
      # cheap and cached on every platform.
      serif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Serif";
      };
      sansSerif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Sans";
      };
      # Prebuilt emoji font: Stylix's noto default drags in the afdko/nototools
      # build chain (broken on darwin). See #48.
      emoji = {
        package = pkgs.twemoji-color-font;
        name = "Twitter Color Emoji";
      };
      # 13 pt for both terminals. Stylix's ghostty target scales this 4/3 on
      # darwin; ghostty.nix counters that so both terminals share one size.
      sizes.terminal = 13;
    };

    opacity.terminal = 0.95;

    targets = {
      starship.enable = true;
      tmux.enable = true;
      fish.enable = true;
      fzf.enable = true;
      bat.enable = true;
      ghostty.enable = true;
      wezterm.enable = true;
      # The only thing that installs `stylix.fonts.*.package` — without it the
      # slots above are names only. Off on headless hosts: their terminals are
      # remote, so fonts render client-side.
      font-packages.enable = hasGui;
      # Remaps the fontconfig generic aliases (monospace/serif/…) to the chosen
      # slots, so any app resolving "monospace" gets Pragmasevka. Gated with
      # fonts.fontconfig.enable below (the alias mapping only bites where
      # fontconfig is the resolver — Linux, not CoreText/macOS).
      fontconfig.enable = pkgs.stdenv.hostPlatform.isLinux && hasGui;
      # Nvim is driven by our own theme.lua generator; skip Stylix's
      # neovim target.
      neovim.enable = false;
    };
  };

  # Fontconfig only discovers nix-profile fonts (the font-packages install
  # path) through HM's user conf; without it Pragmasevka is installed but
  # invisible to Linux apps.
  fonts.fontconfig.enable = pkgs.stdenv.hostPlatform.isLinux && hasGui;
}
