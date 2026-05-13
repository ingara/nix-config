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

    # zjstatus status-bar layout — KDL with hex colors hardcoded into
    # `#[bg=…,fg=…]` segments. Template through stylix.colors so mode
    # indicators / tabs / git branch / clock follow the active scheme.
    "zellij/layouts/zjstatus.kdl".text = ''
      layout {
          default_tab_template {
              pane size=1 borderless=true {
                  plugin location="https://github.com/dj95/zjstatus/releases/latest/download/zjstatus.wasm" {
                      format_left   "{mode}{pipe_zjstatus_hints}"
                      format_center "{tabs}"
                      format_right  "{command_git_branch}{datetime}{command_session}"
                      format_space  ""
                      format_hide_on_overlength "true"
                      format_precedence "lcr"

                      border_enabled  "false"
                      border_char     "─"
                      border_format   "#[fg=${c.base03}]{char}"
                      border_position "top"

                      hide_frame_for_single_pane "false"

                      // Mode indicators — colors track myOptions.theme.scheme
                      mode_locked        "#[bg=${c.base04},fg=${c.base00},bold]  LOCKED "
                      mode_normal        "#[bg=${c.base0D},fg=${c.base00},bold]  NORMAL "
                      mode_pane          "#[bg=${c.base0B},fg=${c.base00},bold]  PANE "
                      mode_tab           "#[bg=${c.base0E},fg=${c.base00},bold]  TAB "
                      mode_resize        "#[bg=${c.base0A},fg=${c.base00},bold]  RESIZE "
                      mode_move          "#[bg=${c.base0C},fg=${c.base00},bold]  MOVE "
                      mode_scroll        "#[bg=${c.base0F},fg=${c.base00},bold]  SCROLL "
                      mode_enter_search  "#[bg=${c.base09},fg=${c.base00},bold]  SEARCH "
                      mode_search        "#[bg=${c.base09},fg=${c.base00},bold]  SEARCH "
                      mode_rename_tab    "#[bg=${c.base0E},fg=${c.base00},bold]  RENAME TAB "
                      mode_rename_pane   "#[bg=${c.base0B},fg=${c.base00},bold]  RENAME PANE "
                      mode_session       "#[bg=${c.base08},fg=${c.base00},bold]  SESSION "
                      mode_prompt        "#[bg=${c.base0A},fg=${c.base00},bold]  PROMPT "

                      pipe_zjstatus_hints_format "#[fg=${c.base03},bold] {output} "

                      tab_normal              "#[fg=${c.base03}] {index} {name} "
                      tab_normal_fullscreen   "#[fg=${c.base03}] {index} {name} 󰊓 "
                      tab_normal_sync         "#[fg=${c.base03}] {index} {name}  "

                      tab_active              "#[bg=${c.base0D},fg=${c.base00},bold] {index} {name} "
                      tab_active_fullscreen   "#[bg=${c.base0D},fg=${c.base00},bold] {index} {name} 󰊓 "
                      tab_active_sync         "#[bg=${c.base0D},fg=${c.base00},bold] {index} {name}  "

                      command_git_branch_command     "git rev-parse --abbrev-ref HEAD"
                      command_git_branch_format      "#[fg=${c.base0D}]  {stdout} "
                      command_git_branch_interval    "10"
                      command_git_branch_rendermode  "static"

                      datetime        "#[fg=${c.base05},bold] {format} "
                      datetime_format "%H:%M"
                      datetime_timezone "Europe/Oslo"

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
    # Static names; values track the active scheme via stylix.colors.
    "zellij/session-colors.sh".text = ''
      LOCAL_BG=${c.base0D}
      SSH_BG=${c.base0E}
      BASE_BG=${c.base00}
    '';
  };
}
