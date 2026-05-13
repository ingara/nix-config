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
    useGlobalPkgs = false;
    backupFileExtension = "backup";
    users.${user} =
      {
        config,
        pkgs,
        ...
      }:
      {
        imports = [
          inputs.catppuccin.homeModules.catppuccin
          inputs.stylix.homeModules.stylix
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

        # Stylix wiring lives here but is disabled — Phase 3 of the
        # global-theme migration flips this on and removes catppuccin.
        # Until then the targets evaluate but do not apply, so catppuccin
        # remains the visible source of truth.
        #
        # jankyborders is a nix-darwin SYSTEM target (not HM); its wiring
        # lives alongside `services.jankyborders` and gets enabled
        # together with Stylix's darwinModule in Phase 3.5.
        stylix = {
          enable = false;
          base16Scheme = config.lib.myTheme.schemeYaml;
          polarity = config.lib.myTheme.polarity;
          targets = {
            starship.enable = true;
            tmux.enable = true;
            fish.enable = true;
            fzf.enable = true;
            bat.enable = true;
            wezterm.enable = true;
            ghostty.enable = true;
            zellij.enable = true;
            # Nvim is driven by our own theme.lua generator; skip Stylix's
            # neovim target.
            neovim.enable = false;
          };
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
