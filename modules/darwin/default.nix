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
    inputs.stylix.darwinModules.stylix
    ./window-manager.nix
    ./bar.nix
  ];

  # System-level Stylix (currently the only consumer is the jankyborders
  # target, which lives at the nix-darwin SYSTEM scope, not HM). HM-side
  # Stylix wiring is below in `home-manager.users.${user}`.
  stylix = {
    enable = true;
    base16Scheme = "${inputs.tinted-schemes}/base16/${config.myOptions.theme.scheme}.yaml";
    polarity = config.myOptions.theme.polarity;
    targets.jankyborders.enable = true;
  };

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
        pkgs,
        ...
      }:
      {
        imports = [
          ../shared/home/dotfiles.nix
          ./dotfiles.nix
          ../shared/home
        ];

        myOptions.dotfiles.wmBackend = wmBackend;

        # System-level Stylix (above) propagates `enable`, `base16Scheme`,
        # `polarity` into HM via stylix's home-manager-integration module.
        # We only declare HM-specific target toggles here.
        stylix.targets = {
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
