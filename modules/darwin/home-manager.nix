{ config, pkgs, catppuccin, lib, home-manager, ... }:

let
  user = "ingar";
  sharedFiles = import ../shared/files.nix { inherit config lib pkgs; };
  additionalFiles = import ./files.nix { inherit user config pkgs; };
in
{
  imports = [
   # ./dock
  ];

  # It me
  users.users.${user} = {
    name = "${user}";
    home = "/Users/${user}";
    isHidden = false;
    shell = pkgs.fish;
  };

  homebrew = import ./homebrew.nix {} // {
  # homebrew = {
    # This is a module from nix-darwin
    # Homebrew is *installed* via the flake input nix-homebrew
    enable = true;
    # imports = [ ./homebrew.nix ];
    # casks = pkgs.callPackage ./casks.nix {};

    # These app IDs are from using the mas CLI app
    # mas = mac app store
    # https://github.com/mas-cli/mas
    #
    # $ nix shell nixpkgs#mas
    # $ mas search <app name>
    #
    masApps = {
      Fantastical = 975937182;
      "Airmail 5" = 918858936;
      "Amphetamine" = 937984704;
      "Spotica Menu" = 570549457;
      "Balance Lock" = 1019371109;
      "Velja" = 1607635845;
    };
  };

  # Enable home-manager
  home-manager = {
    useGlobalPkgs = true;
    users.${user} = { pkgs, config, lib, ... }:{
      imports = [
        catppuccin.homeManagerModules.catppuccin
        (import ../shared/dotfiles.nix { configPath = "${config.home.homeDirectory}/nix-config"; })
      ];
      catppuccin = {
        flavour = "macchiato";
        enable = false; #TODO: enable?
      };
      home = {
        enableNixpkgsReleaseCheck = false;
        packages = pkgs.callPackage ./packages.nix {};
        file = lib.mkMerge [
          sharedFiles
          additionalFiles
        ];

        stateVersion = "23.11";
      };

      programs = {} // import ../shared/home-manager.nix { inherit config pkgs lib; };

      # Marked broken Oct 20, 2022 check later to remove this
      # https://github.com/nix-community/home-manager/issues/3344
      manual.manpages.enable = false;
    };
  };
  services = {
    sketchybar = {
      enable = true;
      extraPackages = [
        pkgs.sketchybar-app-font
      ];
    };
  };

  # Fully declarative dock using the latest from Nix Store
  # local = {
  #   dock.enable = true;
  #   dock.entries = [
  #     { path = "/Applications/Slack.app/"; }
  #     { path = "/System/Applications/Messages.app/"; }
  #     { path = "/Applications/Firefox.app/"; }
  #     { path = "/Applications/Firefox Developer Edition.app/"; }
  #     { path = "/Applications/Airmail.app/"; }
  #     { path = "/Applications/Spotify.app/"; }
  #     { path = "/Applications/Slack.app/"; }
  #     { path = "${pkgs.alacritty}/Applications/Alacritty.app/"; }
  #     {
  #       path = "${config.users.users.${user}.home}/.local/share/downloads";
  #       section = "others";
  #       options = "--sort name --view grid --display stack";
  #     }
  #   ];
  # };
}
