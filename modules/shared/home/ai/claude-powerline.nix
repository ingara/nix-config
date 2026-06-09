# claude-powerline statusline config — Nix generates
# ~/.config/claude-powerline/config.json from `config.lib.stylix.colors`.
#
# The statusline binary itself is not vendored: Claude Code's `statusLine`
# command runs it via `npx @owloops/claude-powerline` (wired in the private
# managed-settings overlay). This module only owns the *config*, themed from
# the active base16 palette so the statusline recolors with the rest of the
# system on `myOptions.theme.scheme` change.
#
# Same pattern as `sketchybar.nix` / `nvim-theme.nix`: generated file, NOT a
# live-edit dotfile — change this module + rebuild, don't hand-edit the JSON.
#
# Custom-theme color model: each segment takes a `bg` (accent) + `fg` (text
# on that accent). Accent slots map to the base16 palette; `fg` is base00
# (the dark background slot) for contrast on colored segments, or base05 for
# segments left on a neutral background. Context thresholds escalate
# yellow -> red via base0A/base08.
#
# Config schema + segment options: https://github.com/Owloops/claude-powerline
{ config, ... }:

let
  c = config.lib.stylix.colors.withHashtag;

  seg = bg: fg: { inherit bg fg; };

  powerlineConfig = {
    theme = "custom";

    display = {
      style = "tui";
      charset = "unicode";
      padding = 1;
      autoWrap = true;

      lines = [
        {
          segments = {
            directory = {
              enabled = true;
              style = "fish";
            };
            git = {
              enabled = true;
              showSha = false;
              showWorkingTree = true;
              showOperation = true;
              showUpstream = true;
            };
            model.enabled = true;
            context = {
              enabled = true;
              displayStyle = "text";
            };
            session = {
              enabled = true;
              type = "both";
              costSource = "calculated";
            };
            block = {
              enabled = true;
              displayStyle = "text";
            };
          };
        }
      ];
    };

    # Hue legend: base08 red, base0A yellow, base0B green, base0C cyan,
    # base0D blue, base0E magenta, base0F brown; base02/03 neutral grays.
    colors.custom = {
      directory = seg c.base0D c.base00;
      git = seg c.base0B c.base00;
      model = seg c.base0E c.base00;
      session = seg c.base0C c.base00;
      block = seg c.base03 c.base05;
      today = seg c.base02 c.base05;
      context = seg c.base02 c.base05;
      contextWarning = seg c.base0A c.base00;
      contextCritical = seg c.base08 c.base00;
      metrics = seg c.base02 c.base05;
      version = seg c.base03 c.base05;
      tmux = seg c.base0F c.base00;
    };
  };
in
{
  xdg.configFile."claude-powerline/config.json".text = builtins.toJSON powerlineConfig;
}
