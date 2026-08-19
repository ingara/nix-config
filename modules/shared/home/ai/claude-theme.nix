# Claude Code theme generated from the active Stylix base16 palette.
{ config, ... }:

let
  c = config.lib.stylix.colors.withHashtag;
  myTheme = config.lib.myTheme;

  theme = {
    name = "Stylix (${myTheme.scheme})";
    base = if myTheme.polarity == "light" then "light" else "dark";
    overrides = {
      text = c.base05;
      inverseText = c.base00;
      claude = c.base0D;
      inactive = c.base03;
      # Pinned past messages use `subtle`, so they need the same readable
      # foreground as regular message text.
      subtle = c.base05;
      suggestion = c.base0C;
      permission = c.base0E;
      remember = c.base0E;

      success = c.base0B;
      error = c.base08;
      warning = c.base0A;
      merged = c.base0E;

      promptBorder = c.base03;
      planMode = c.base0D;
      autoAccept = c.base0B;
      bashBorder = c.base0E;
      ide = c.base0C;
      fastMode = c.base09;

      userMessageBackground = c.base02;
      userMessageBackgroundHover = c.base01;
      bashMessageBackgroundColor = c.base01;
      memoryBackgroundColor = c.base01;
      selectionBg = c.base02;

      rate_limit_fill = c.base0D;
      rate_limit_empty = c.base02;
      briefLabelYou = c.base0C;
      briefLabelClaude = c.base0D;

      claudeShimmer = c.base0D;
      warningShimmer = c.base0A;
      permissionShimmer = c.base0E;
      promptBorderShimmer = c.base04;
      inactiveShimmer = c.base04;
      fastModeShimmer = c.base09;

      red_FOR_SUBAGENTS_ONLY = c.base08;
      orange_FOR_SUBAGENTS_ONLY = c.base09;
      yellow_FOR_SUBAGENTS_ONLY = c.base0A;
      green_FOR_SUBAGENTS_ONLY = c.base0B;
      cyan_FOR_SUBAGENTS_ONLY = c.base0C;
      blue_FOR_SUBAGENTS_ONLY = c.base0D;
      purple_FOR_SUBAGENTS_ONLY = c.base0E;
      pink_FOR_SUBAGENTS_ONLY = c.base0F;

      rainbow_red = c.base08;
      rainbow_orange = c.base09;
      rainbow_yellow = c.base0A;
      rainbow_green = c.base0B;
      rainbow_blue = c.base0C;
      rainbow_indigo = c.base0D;
      rainbow_violet = c.base0E;

      rainbow_red_shimmer = c.base08;
      rainbow_orange_shimmer = c.base09;
      rainbow_yellow_shimmer = c.base0A;
      rainbow_green_shimmer = c.base0B;
      rainbow_blue_shimmer = c.base0C;
      rainbow_indigo_shimmer = c.base0D;
      rainbow_violet_shimmer = c.base0E;
    };
  };
in
{
  xdg.configFile."claude/themes/stylix.json".text = builtins.toJSON theme;
}
