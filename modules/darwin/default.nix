# Darwin platform entry point — user account, home-manager wiring, and
# imports of darwin-only concerns (window manager, status/border bar).
#
# Homebrew lives in `./homebrew.nix`; it's imported from `public/hosts/darwin`
# rather than from here so the HM-less darwin test builds can skip it.
{
  config,
  inputs,
  ...
}:

let
  user = config.myOptions.user.username;
  wmBackend = config.myOptions.windowManager.backend;
in
{
  imports = [
    ./window-manager.nix
    ./bar.nix
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
        ...
      }:
      {
        imports = [
          inputs.catppuccin.homeModules.catppuccin
          ../shared/home/dotfiles.nix
          ./dotfiles.nix
          ../shared/home
        ];

        myOptions.dotfiles.wmBackend = wmBackend;

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
          };
          sessionPath = [
            "$HOME/go/bin"
          ];

          stateVersion = "23.11";
        };

        # Marked broken Oct 20, 2022 check later to remove this
        # https://github.com/nix-community/home-manager/issues/3344
        manual.manpages.enable = false;
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
