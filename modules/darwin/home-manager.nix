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

  # Enable home-manager
  home-manager = {
    useGlobalPkgs = true;
    users.${user} = { pkgs, config, lib, ... }:{
      imports = [
        catppuccin.homeManagerModules.catppuccin
        (import ../shared/dotfiles.nix { configPath = "${config.home.homeDirectory}/nix-config"; })
      ];
      catppuccin = {
        flavor = "macchiato";
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

      programs = { } // import ../shared/home-manager.nix { inherit config pkgs lib; };

      # Marked broken Oct 20, 2022 check later to remove this
      # https://github.com/nix-community/home-manager/issues/3344
      manual.manpages.enable = false;
    };
  };
  # Can't get this to work. Running through homebrew instead.
  # services = {
  #   sketchybar = {
  #     enable = true;
  #     extraPackages = [
  #       pkgs.sketchybar-app-font
  #     ];
  #   };
  # };

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
