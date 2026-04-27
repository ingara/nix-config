{ config, lib, ... }:

let
  configPath = config.myOptions.dotfiles.repoRoot;
  inherit (config.myOptions.dotfiles) wmBackend;
  mutable = config.myOptions.mutableDotfiles;

  # Base dotfiles (always linked)
  baseDots = {
    "lazygit/config.yml" = "lazygit.yml";
    "nvim" = "nvim";
    "ghostty" = "ghostty";
    "zellij" = "zellij";
    "sketchybar" = "sketchybar";
    "wezterm/extra" = "wezterm/extra";
    "git/extra" = "git-extra";
    "claude/statusline-command.sh" = "claude/statusline-command.sh";
  };

  # Yabai-specific dotfiles
  yabaiDots = {
    "yabai" = "yabai";
    "skhd/skhdrc" = "skhdrc";
  };

  # AeroSpace-specific dotfiles
  aerospaceDots = {
    "aerospace" = "aerospace";
  };

  # OmniWM-specific dotfiles
  #
  # `omniwm/settings.toml` is intentionally NOT symlinked: OmniWM rewrites the
  # file via atomic rename(2) on every GUI save, which replaces our symlink
  # with a real file and breaks home-manager activation on the next switch.
  # GUI is the source of truth until upstream lands either an
  # incremental-export flag (see BarutSRB/OmniWM#109, #169) or swaps the
  # atomic write for `FileManager.replaceItemAt` (not yet filed).
  omniwmDots = { };

  # Combine based on selected backend
  dots =
    baseDots
    // (if wmBackend == "yabai" then yabaiDots else { })
    // (if wmBackend == "aerospace" then aerospaceDots else { })
    // (if wmBackend == "omniwm" then omniwmDots else { });

  symlink = _key: value: {
    source =
      if mutable then
        config.lib.file.mkOutOfStoreSymlink "${configPath}/dotfiles/${value}"
      else
        ../../dotfiles + "/${value}";
  };
in
{
  imports = [ ./opencode.nix ];

  options.myOptions.dotfiles = {
    wmBackend = lib.mkOption {
      type = lib.types.enum [
        "yabai"
        "aerospace"
        "omniwm"
        "none"
      ];
      default = "none";
    };
  };

  config = {
    xdg.configFile = lib.mapAttrs symlink dots;
  };
}
