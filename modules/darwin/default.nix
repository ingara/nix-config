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
in
{
  imports = [
    inputs.stylix.darwinModules.stylix
    ./window-manager.nix
    ./skhd.nix
    ./bar.nix
    ./claude-code.nix
  ];

  # System-level Stylix (currently the only consumer is the jankyborders
  # target, which lives at the nix-darwin SYSTEM scope, not HM). HM-side
  # Stylix wiring is below in `home-manager.users.${user}`.
  stylix = {
    enable = true;
    base16Scheme = "${inputs.tinted-schemes}/base16/${config.myOptions.theme.scheme}.yaml";
    polarity = config.myOptions.theme.polarity;
    targets.jankyborders.enable = true;
    # Fonts are owned by HM Stylix (shared/home/stylix-base.nix); without this
    # off-switch the autoEnabled system-scope font-packages target would
    # install the four never-referenced stylix.fonts defaults system-wide
    # (incl. the noto emoji whose afdko source build broke a switch — #48).
    targets.font-packages.enable = false;
  };

  users.users.${user} = {
    name = "${user}";
    home = "/Users/${user}";
    isHidden = false;
  };

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
          inputs.paneru.homeModules.paneru
          ./dotfiles.nix
          ./colima.nix
          ./paneru.nix
          ./nehir.nix
          ../shared/home
          ../shared/home/stylix-base.nix
        ];

        # Platform-specific Stylix target extras on top of the shared core
        # (../shared/home/stylix-base.nix).
        stylix.targets = {
          # No GTK apps on darwin; skip the target so Stylix doesn't wire
          # adw-gtk3 / fonts / gtk.css into HM here.
          gtk.enable = false;
        };

        home = {
          enableNixpkgsReleaseCheck = false;
          packages = pkgs.callPackage ./packages.nix { };
          stateVersion = "23.11";
        };

        # Workaround for broken manpage build:
        # https://github.com/nix-community/home-manager/issues/3344
        manual.manpages.enable = false;
      };
  };
}
