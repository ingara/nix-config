# Theme helper — resolves `myOptions.theme.scheme` into a path that
# Stylix (and any other base16-aware consumer) can read.
#
# Exposed as `config.lib.myTheme` so HM modules can interpolate without
# the full `inputs` arg dance. Stylix wiring lives in stylix-base.nix
# (shared core: scheme, fonts, opacity, cross-platform targets) plus
# per-platform target extras; this module only resolves the scheme.
{
  config,
  inputs,
  lib,
  ...
}:

let
  cfg = config.myOptions.theme;
  schemeYaml = "${inputs.tinted-schemes}/base16/${cfg.scheme}.yaml";
  schemeLines = lib.splitString "\n" (builtins.readFile schemeYaml);
  base05 = lib.findFirst (lib.hasPrefix "  base05:") null schemeLines;
  correctedSchemeYaml = builtins.toFile "${cfg.scheme}.yaml" (
    lib.concatStringsSep "\n" (
      map (
        line:
        if lib.hasPrefix "  base07:" line then "  base07:${lib.removePrefix "  base05:" base05}" else line
      ) schemeLines
    )
  );
in
{
  # No `options.lib.myTheme` declaration — HM's `options.lib` is already
  # typed `attrsOf attrs`, which doesn't permit nested options. We simply
  # write to `config.lib.myTheme` and consumers read it.
  config.lib.myTheme = {
    inherit (cfg) scheme polarity;
    inherit schemeYaml;
    stylixSchemeYaml =
      if
        builtins.elem cfg.scheme [
          "rose-pine"
          "rose-pine-moon"
        ]
      then
        correctedSchemeYaml
      else
        schemeYaml;
  };
}
