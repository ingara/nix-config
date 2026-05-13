# easy-hosts presets — the module lists previously hidden inside
# mkDarwinHost / mkNixosHost / mkHeadlessServer builder functions.
#
# Organization:
#   - easy-hosts.shared.modules     → every host (options.nix is the myOptions schema)
#   - easy-hosts.perClass.nixos     → every nixos / wsl host (class=wsl aliased to nixos)
#   - easy-hosts.perClass.darwin    → every darwin host
#   - easy-hosts.perTag.server      → headless servers (disko + qemu-guest + base.nix)
#   - easy-hosts.additionalClasses  → { wsl = "nixos"; } so class=wsl resolves to nixos
#
# Home-manager wiring lives in perClass.{nixos,darwin} because both classes
# want the same mkSharedModules trick (propagate system-level myOptions to
# HM via `home-manager.sharedModules` with mkDefault priority).
{ inputs, ... }:
let
  # Propagate system-level myOptions to home-manager. Returns a list of
  # modules; first registers the options schema, second assigns current
  # system-level values to HM with mkDefault priority (so per-HM overrides
  # still win).
  mkSharedHmOptionsModule =
    { config, lib }:
    [
      ../modules/shared/options.nix
      ../modules/shared/nixpkgs.nix
      {
        myOptions = {
          user = {
            username = lib.mkDefault config.myOptions.user.username;
            fullName = lib.mkDefault config.myOptions.user.fullName;
            email = lib.mkDefault config.myOptions.user.email;
            signingKey = lib.mkDefault config.myOptions.user.signingKey;
          };
          dotfiles.repoRoot = lib.mkDefault config.myOptions.dotfiles.repoRoot;
          hasGui = lib.mkDefault config.myOptions.hasGui;
          mutableDotfiles = lib.mkDefault config.myOptions.mutableDotfiles;
          zellijAutoAttach = lib.mkDefault config.myOptions.zellijAutoAttach;
          sshSignProgram = lib.mkDefault config.myOptions.sshSignProgram;
          gitCredentialHelper = lib.mkDefault config.myOptions.gitCredentialHelper;
          opencode.hostClass = lib.mkDefault config.myOptions.opencode.hostClass;
        };
      }
    ];
in
{
  easy-hosts = {
    shared.modules = [
      ../modules/shared/options.nix
    ];

    perClass =
      class:
      {
        nixos = {
          modules = [
            inputs.catppuccin.nixosModules.catppuccin
            inputs.home-manager.nixosModules.home-manager
            (
              { config, lib, ... }:
              {
                myOptions.dotfiles.repoRoot = lib.mkDefault "/home/user/nix-config";
                home-manager = {
                  useGlobalPkgs = false;
                  useUserPackages = true;
                  extraSpecialArgs = { inherit inputs; };
                  sharedModules = mkSharedHmOptionsModule { inherit config lib; };
                  users.${config.myOptions.user.username} =
                    { config, ... }:
                    {
                      imports = [
                        ../modules/linux/home-manager.nix
                        inputs.catppuccin.homeModules.catppuccin
                        inputs.stylix.homeModules.stylix
                      ];

                      # Stylix wiring (disabled until Phase 3 cutover).
                      # Headless servers still benefit from theming:
                      # shell tools running server-side embed 24-bit ANSI
                      # colors into the SSH session output.
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
                          neovim.enable = false;
                        };
                      };
                    };
                };
              }
            )
          ];
        };

        darwin = {
          modules = [
            inputs.home-manager.darwinModules.home-manager
            inputs.nix-homebrew.darwinModules.nix-homebrew
            (
              { config, lib, ... }:
              {
                myOptions.dotfiles.repoRoot = lib.mkDefault "/Users/user/nix-config";

                nix-homebrew = {
                  user = config.myOptions.user.username;
                  enable = true;
                  enableRosetta = true;
                  mutableTaps = false;

                  taps = {
                    "homebrew/homebrew-core" = inputs.homebrew-core;
                    "homebrew/homebrew-cask" = inputs.homebrew-cask;
                    "homebrew/homebrew-bundle" = inputs.homebrew-bundle;
                    "felixkratz/homebrew-formulae" = inputs.homebrew-felixkratz;
                    "satococoa/homebrew-tap" = inputs.homebrew-satococoa;
                    "withgraphite/homebrew-tap" = inputs.homebrew-graphite;
                    "nikitabobko/homebrew-tap" = inputs.homebrew-aerospace;
                    "theboredteam/homebrew-boring-notch" = inputs.homebrew-boring-notch;
                    "BarutSRB/homebrew-tap" = inputs.homebrew-omniwm;
                  };
                };

                # HM wiring on darwin. Users are declared inside
                # `../hosts/darwin`; here we just inject sharedModules
                # so the myOptions propagation trick reaches every user.
                home-manager.extraSpecialArgs = { inherit inputs; };
                home-manager.sharedModules = mkSharedHmOptionsModule { inherit config lib; };
              }
            )
            ../hosts/darwin
          ];
        };
      }
      .${class} or {
        modules = [ ];
      };

    perTag =
      tag:
      {
        server = {
          modules = [
            inputs.disko.nixosModules.disko
            (
              { modulesPath, ... }:
              {
                imports = [
                  ../hosts/nixos/base.nix
                  (modulesPath + "/profiles/qemu-guest.nix")
                ];
              }
            )
          ];
        };
      }
      .${tag} or {
        modules = [ ];
      };
  };
}
