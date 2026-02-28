{
  config,
  pkgs,
  catppuccin,
  lib,
  home-manager,
  userConfig,
  ...
}:

let
  user = userConfig.username;
  wmBackend = config.myOptions.windowManager.backend or "yabai";
in
{
  imports = [
    ./window-manager.nix
  ];

  # It me
  users.users.${user} = {
    name = "${user}";
    home = "/Users/${user}";
    isHidden = false;
    # shell = pkgs.fish;
  };

  # Enable home-manager
  home-manager = {
    useGlobalPkgs = true;
    backupFileExtension = "backup";
    users.${user} =
      {
        pkgs,
        config,
        lib,
        ...
      }:
      {
        imports = [
          catppuccin.homeModules.catppuccin
          (import ../shared/dotfiles.nix {
            configPath = "${config.home.homeDirectory}/nix-config";
            inherit wmBackend;
          })
          (import ./dotfiles.nix { configPath = "${config.home.homeDirectory}/nix-config"; })
        ];
        catppuccin = {
          flavor = "macchiato";
          enable = true;
          starship.enable = true;
          tmux.enable = true;
          fzf.enable = true;
          delta.enable = true;
          bat.enable = true;
          fish.enable = true;
        };
        home = {
          enableNixpkgsReleaseCheck = false;
          packages = pkgs.callPackage ./packages.nix { };
          file = { };
          sessionVariables = {
            PAGER = "less";
            LESS = "-R --quit-if-one-screen --no-init";
            GOPRIVATE = "github.com/soolv/*";
          };
          sessionPath = [
            "$HOME/go/bin"
          ];

          stateVersion = "23.11";
        };

        programs =
          { }
          // import ../shared/home-manager.nix {
            inherit
              config
              pkgs
              lib
              userConfig
              ;
            gitCredentialHelper = "osxkeychain";
            sshSignProgram = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
          };

        # Marked broken Oct 20, 2022 check later to remove this
        # https://github.com/nix-community/home-manager/issues/3344
        manual.manpages.enable = false;
      };
  };

  # Window manager services (yabai/skhd) are managed by window-manager.nix
  services = {
    sketchybar = {
      enable = true;
    };

    # https://mynixos.com/options/services.jankyborders
    jankyborders = {
      enable = true;
      style = "round";
      width = 3.0;
      hidpi = true;
      #active_color= "0xffcdd6f4";  # Lavender
      active_color = "0xffee99a0"; # Maroon
      inactive_color = "0xff45475a"; # Surface0
      order = "above";
    };
  };

  launchd.user.agents = {
    sketchybar.serviceConfig = {
      StandardOutPath = "/tmp/sketchybar.log";
      StandardErrorPath = "/tmp/sketchybar.log";
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
