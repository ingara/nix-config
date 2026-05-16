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
    # The inner block name must match `theme "<name>"` in zellij's
    # config.kdl AND the filename (`stylix.kdl`). Stylix's upstream
    # hm.nix uses `default` here, which silently falls back to
    # zellij's built-in default theme (bright green frames).
    themes.stylix = {
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
      frame_unselected = {
        base = c.base04;
        background = c.base00;
        emphasis_0 = c.base03;
        emphasis_1 = c.base03;
        emphasis_2 = c.base03;
        emphasis_3 = c.base03;
      };
      frame_selected = {
        base = c.base0D;
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

    # zjstatus status-bar layout — uses *named* ANSI colors (`blue`,
    # `magenta`, …) instead of hex. The terminal resolves them against
    # its palette at render time, and ghostty's palette is templated by
    # stylix above. Net effect: status-bar colors track the active
    # scheme automatically, even for resurrected sessions whose
    # session-layout.kdl was cached under a previous scheme — the names
    # are what's baked, not the resolved values.
    #
    # Three modes use base16 slots that have no 16-color ANSI
    # equivalent (base04 LOCKED, base0F SCROLL, base09 SEARCH) and fall
    # back to visually-near substitutes (`bright_black`, `bright_red`,
    # `yellow`).
    #
    # git branch and clock widgets are intentionally absent — starship
    # shows both on every prompt; duplicating them in the status bar is
    # just extra surface area.
    "zellij/layouts/zjstatus.kdl".text = ''
      layout {
          default_tab_template {
              pane size=1 borderless=true {
                  plugin location="https://github.com/dj95/zjstatus/releases/latest/download/zjstatus.wasm" {
                      format_left   "{mode}{pipe_zjstatus_hints}"
                      format_center "{tabs}"
                      format_right  "{command_session}"
                      format_space  ""
                      format_hide_on_overlength "true"
                      format_precedence "lcr"

                      border_enabled  "false"
                      border_char     "─"
                      border_format   "#[fg=bright_black]{char}"
                      border_position "top"

                      hide_frame_for_single_pane "false"

                      mode_locked        "#[bg=bright_black,fg=black,bold]  LOCKED "
                      mode_normal        "#[bg=blue,fg=black,bold]  NORMAL "
                      mode_pane          "#[bg=green,fg=black,bold]  PANE "
                      mode_tab           "#[bg=magenta,fg=black,bold]  TAB "
                      mode_resize        "#[bg=yellow,fg=black,bold]  RESIZE "
                      mode_move          "#[bg=cyan,fg=black,bold]  MOVE "
                      mode_scroll        "#[bg=bright_red,fg=black,bold]  SCROLL "
                      mode_enter_search  "#[bg=yellow,fg=black,bold]  SEARCH "
                      mode_search        "#[bg=yellow,fg=black,bold]  SEARCH "
                      mode_rename_tab    "#[bg=magenta,fg=black,bold]  RENAME TAB "
                      mode_rename_pane   "#[bg=green,fg=black,bold]  RENAME PANE "
                      mode_session       "#[bg=red,fg=black,bold]  SESSION "
                      mode_prompt        "#[bg=yellow,fg=black,bold]  PROMPT "

                      pipe_zjstatus_hints_format "#[fg=bright_black,bold] {output} "

                      tab_normal              "#[fg=bright_black] {index} {name} "
                      tab_normal_fullscreen   "#[fg=bright_black] {index} {name} 󰊓 "
                      tab_normal_sync         "#[fg=bright_black] {index} {name}  "

                      tab_active              "#[bg=blue,fg=black,bold] {index} {name} "
                      tab_active_fullscreen   "#[bg=blue,fg=black,bold] {index} {name} 󰊓 "
                      tab_active_sync         "#[bg=blue,fg=black,bold] {index} {name}  "

                      command_session_command     "zellij-session-display.sh"
                      command_session_format      "{stdout}"
                      command_session_interval    "0"
                      command_session_rendermode  "dynamic"
                  }
              }
              children
          }
      }
    '';

    # Sourced by zellij-session-display.sh to color the session segment.
    # Named ANSI colors — resolved against the terminal palette at
    # render time, so scheme changes apply without regenerating this
    # file.
    "zellij/session-colors.sh".text = ''
      LOCAL_BG=blue
      SSH_BG=magenta
      BASE_BG=black
    '';
  };
}
