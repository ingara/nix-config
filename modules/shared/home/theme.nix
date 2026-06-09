# Theme helper — resolves `myOptions.theme.scheme` into a path that
# Stylix (and any other base16-aware consumer) can read.
#
# Exposed as `config.lib.myTheme` so HM modules can interpolate without
# the full `inputs` arg dance. Stylix wiring lives per-platform (Darwin
# HM, Fedora HM, NixOS HM preset); this module deliberately does NOT
# set `stylix.*` to keep eval cross-platform-safe.
{
  config,
  inputs,
  ...
}:

let
  cfg = config.myOptions.theme;
in
{
  # No `options.lib.myTheme` declaration — HM's `options.lib` is already
  # typed `attrsOf attrs`, which doesn't permit nested options. We simply
  # write to `config.lib.myTheme` and consumers read it.
  config.lib.myTheme = {
    inherit (cfg) scheme polarity;
    schemeYaml = "${inputs.tinted-schemes}/base16/${cfg.scheme}.yaml";
  };
}
