# Terminal theme bridges — ghostty + zellij.
#
# Stylix's `programs.<app>.themes` HM targets only write theme files
# when `programs.<app>.enable = true`. Our ghostty + zellij configs
# are dotfile-symlinked (live-edit), not HM-managed, so those targets
# are no-ops. Bypass them by writing the theme files ourselves from
# `config.lib.stylix.colors`.
#
# The dotfile-side configs reference `theme = stylix` (ghostty) and
# `theme "stylix"` (zellij); the files emitted here satisfy those
# references.
{ config, lib, ... }:

let
  c = config.lib.stylix.colors.withHashtag;

  # Zellij theme attrs, identical structure to Stylix's
  # modules/zellij/hm.nix (programs.zellij.themes.stylix). Rendered to
  # KDL via lib.hm.generators.toKDL below.
  zellijThemeAttrs = {
    themes.default = {
      text_unselected = {
        base = c.base05;
        background = c.base01;
        emphasis_0 = c.base09;
        emphasis_1 = c.base0C;
        emphasis_2 = c.base0B;
        emphasis_3 = c.base0F;
      };
      text_selected = {
        base = c.base05;
        background = c.base04;
        emphasis_0 = c.base09;
        emphasis_1 = c.base0C;
        emphasis_2 = c.base0B;
        emphasis_3 = c.base0F;
      };
      ribbon_selected = {
        base = c.base01;
        background = c.base0E;
        emphasis_0 = c.base08;
        emphasis_1 = c.base09;
        emphasis_2 = c.base0F;
        emphasis_3 = c.base0D;
      };
      ribbon_unselected = {
        base = c.base05;
        background = c.base02;
        emphasis_0 = c.base08;
        emphasis_1 = c.base05;
        emphasis_2 = c.base0D;
        emphasis_3 = c.base0F;
      };
      table_title = {
        base = c.base0E;
        background = c.base00;
        emphasis_0 = c.base09;
        emphasis_1 = c.base0C;
        emphasis_2 = c.base0B;
        emphasis_3 = c.base0F;
      };
      table_cell_selected = {
        base = c.base05;
        background = c.base04;
        emphasis_0 = c.base09;
        emphasis_1 = c.base0C;
        emphasis_2 = c.base0B;
        emphasis_3 = c.base0F;
      };
      table_cell_unselected = {
        base = c.base05;
        background = c.base01;
        emphasis_0 = c.base09;
        emphasis_1 = c.base0C;
        emphasis_2 = c.base0B;
        emphasis_3 = c.base0F;
      };
      list_selected = {
        base = c.base05;
        background = c.base04;
        emphasis_0 = c.base09;
        emphasis_1 = c.base0C;
        emphasis_2 = c.base0B;
        emphasis_3 = c.base0F;
      };
      list_unselected = {
        base = c.base05;
        background = c.base01;
        emphasis_0 = c.base09;
        emphasis_1 = c.base0C;
        emphasis_2 = c.base0B;
        emphasis_3 = c.base0F;
      };
      frame_selected = {
        base = c.base0E;
        background = c.base00;
        emphasis_0 = c.base09;
        emphasis_1 = c.base0C;
        emphasis_2 = c.base0F;
        emphasis_3 = c.base00;
      };
      frame_highlight = {
        base = c.base08;
        background = c.base00;
        emphasis_0 = c.base0F;
        emphasis_1 = c.base09;
        emphasis_2 = c.base09;
        emphasis_3 = c.base09;
      };
      exit_code_success = {
        base = c.base0B;
        background = c.base00;
        emphasis_0 = c.base0C;
        emphasis_1 = c.base01;
        emphasis_2 = c.base0F;
        emphasis_3 = c.base0D;
      };
      exit_code_error = {
        base = c.base08;
        background = c.base00;
        emphasis_0 = c.base0A;
        emphasis_1 = c.base00;
        emphasis_2 = c.base00;
        emphasis_3 = c.base00;
      };
      multiplayer_user_colors = {
        player_1 = c.base0F;
        player_2 = c.base0D;
        player_3 = c.base00;
        player_4 = c.base0A;
        player_5 = c.base0C;
        player_6 = c.base00;
        player_7 = c.base08;
        player_8 = c.base00;
        player_9 = c.base00;
        player_10 = c.base00;
      };
    };
  };
in
{
  config.xdg.configFile = {
    # Ghostty's theme file format is plain key-value with `palette`
    # repeated per index.
    "ghostty/themes/stylix".text = ''
      background = ${c.base00}
      foreground = ${c.base05}
      cursor-color = ${c.base05}
      selection-background = ${c.base02}
      selection-foreground = ${c.base05}
      palette = 0=${c.base00}
      palette = 1=${c.base08}
      palette = 2=${c.base0B}
      palette = 3=${c.base0A}
      palette = 4=${c.base0D}
      palette = 5=${c.base0E}
      palette = 6=${c.base0C}
      palette = 7=${c.base05}
      palette = 8=${c.base03}
      palette = 9=${c.base08}
      palette = 10=${c.base0B}
      palette = 11=${c.base0A}
      palette = 12=${c.base0D}
      palette = 13=${c.base0E}
      palette = 14=${c.base0C}
      palette = 15=${c.base07}
    '';

    # Zellij theme is structured KDL; render via HM's toKDL generator.
    "zellij/themes/stylix.kdl".text = lib.hm.generators.toKDL { } zellijThemeAttrs;
  };
}
