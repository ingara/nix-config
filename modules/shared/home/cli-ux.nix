# Portable, credential-free terminal UX for both operator and standalone HM
# profiles. Keep session mutation and operator-only tools in their owning
# modules rather than growing this bundle into the full shared HM profile.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  capabilities = import ./cli-ux-capabilities.nix { inherit pkgs; };
  palette = lib.genAttrs (map (index: "base${index}") [
    "00"
    "01"
    "02"
    "03"
    "04"
    "05"
    "06"
    "07"
    "08"
    "09"
    "0A"
    "0B"
    "0C"
    "0D"
    "0E"
    "0F"
  ]) (slot: config.lib.stylix.colors.withHashtag.${slot});
  stylixTargets = {
    starship.enable = true;
    fish.enable = true;
    fzf.enable = true;
    bat.enable = true;
    bottom.enable = true;
  };
in
{
  imports = [
    ./theme.nix
    ./fish-portable.nix
    ./starship.nix
    ./cli-tools/bat.nix
    ./cli-tools/fzf.nix
    ./cli-tools/zoxide.nix
  ];

  config = {
    home.packages =
      capabilities.rawPackages ++ lib.optional (!config.programs.git.enable) capabilities.packages.git;

    programs = {
      fish.package = capabilities.packages.fish;
      starship.package = capabilities.packages.starship;
      bat.package = capabilities.packages.bat;
      fzf.package = capabilities.packages.fzf;
      zoxide.package = capabilities.packages.zoxide;
      bottom = {
        enable = true;
        package = capabilities.packages.bottom;
      };
    };

    programs.eza = {
      enable = true;
      package = capabilities.packages.eza;
      enableBashIntegration = false;
      enableFishIntegration = false;
      enableZshIntegration = false;
    };

    # starship.nix reads config.lib.stylix.colors directly, so the bundle owns
    # the palette dependency rather than relying on an outer profile to provide it.
    stylix = {
      enable = true;
      # The theme helper corrects the dark Rosé Pine ports' base07 from base05.
      base16Scheme = config.lib.myTheme.stylixSchemeYaml;
      polarity = config.lib.myTheme.polarity;
      targets = stylixTargets;
    };

    myOptions.developerEnvironmentParity = {
      packages = {
        bat = {
          package = capabilities.packages.bat;
          commands = [ "bat" ];
        };
        bottom = {
          package = capabilities.packages.bottom;
          commands = [ "btm" ];
        };
        broot = {
          package = capabilities.packages.broot;
          commands = [ "broot" ];
        };
        eza = {
          package = capabilities.packages.eza;
          commands = [ "eza" ];
        };
        fish = {
          package = capabilities.packages.fish;
          commands = [ "fish" ];
        };
        fzf = {
          package = capabilities.packages.fzf;
          commands = [ "fzf" ];
        };
        git = {
          package = config.programs.git.package;
          commands = [ "git" ];
        };
        starship = {
          package = capabilities.packages.starship;
          commands = [ "starship" ];
        };
        zoxide = {
          package = capabilities.packages.zoxide;
          commands = [ "zoxide" ];
        };
      };
      surfaces.cliUx = {
        bottom.enable = config.programs.bottom.enable;
        eza = {
          inherit (config.programs.eza)
            enable
            enableBashIntegration
            enableFishIntegration
            enableZshIntegration
            ;
        };
        theme = {
          inherit palette;
          stylixTargets = lib.mapAttrs (name: _: {
            enable = config.stylix.targets.${name}.enable;
          }) stylixTargets;
          scheme = config.myOptions.theme.scheme;
          polarity = config.lib.myTheme.polarity;
        };
      };
    };
  };
}
