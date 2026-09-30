# easy-hosts presets — the shared/perClass/perTag module bundles.
#
# Home-manager wiring lives in perClass.{nixos,darwin} because both classes
# want the same mkSharedHmOptionsModule trick.
{ inputs, ... }:
let
  # Propagate system-level myOptions to home-manager: register the options
  # schema, then assign current system-level values with mkDefault priority
  # (so per-HM overrides still win).
  mkSharedHmOptionsModule =
    { config, lib }:
    let
      forwardedMyOptions = config.myOptions // {
        developerEnvironmentParity = builtins.removeAttrs config.myOptions.developerEnvironmentParity [
          "projection"
        ];
      };
    in
    [
      ../modules/shared/options.nix
      ../modules/shared/nixpkgs.nix
      {
        # Forward the system-scope myOptions inputs to HM at mkDefault
        # priority (a per-HM override still wins). Both scopes import the
        # same options.nix, so this generically covers every leaf (theme,
        # user, dotfiles, ...) instead of a hand-enumerated list that
        # silently drops whichever option the list forgot.
        # developerEnvironmentParity.projection is output-only and read-only;
        # HM computes it from the owner registries instead of accepting the
        # system scope's empty value as a second definition.
        #
        # `windowManager.enabled` is a listOf, which merges/concatenates
        # instead of overriding by default, so it needs its own mkForce to
        # stay the single definition despite any stray HM-side definition
        # of the same list.
        myOptions = lib.mkMerge [
          (lib.mkDefault forwardedMyOptions)
          {
            windowManager.enabled = lib.mkForce config.myOptions.windowManager.enabled;
          }
        ];
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
            ../hosts/nixos/base.nix
            inputs.home-manager.nixosModules.home-manager
            (
              { config, lib, ... }:
              {
                myOptions.dotfiles.repoRoot = lib.mkDefault "/home/user/nix-config";
                home-manager = {
                  useGlobalPkgs = false;
                  useUserPackages = true;
                  # Move pre-existing files that HM doesn't recognize aside
                  # instead of erroring; matches the Darwin entry point.
                  backupFileExtension = "backup";
                  extraSpecialArgs = { inherit inputs; };
                  sharedModules = mkSharedHmOptionsModule { inherit config lib; };
                  users.${config.myOptions.user.username} =
                    { ... }:
                    {
                      imports = [
                        ../modules/linux/home-manager.nix
                        inputs.stylix.homeModules.stylix
                        ../modules/shared/home/stylix-base.nix
                      ];

                      # Headless servers benefit from theming too: shell
                      # tools running server-side embed 24-bit ANSI colors
                      # into the SSH session output, so consistency with
                      # the workstation requires matching palettes.
                      #
                      # `autoEnable = false` — Stylix would otherwise
                      # auto-enable GUI-ish targets (GTK, dconf, etc.)
                      # whose activation hooks need a dbus session and
                      # fail on headless machines (`GDBus.Error:
                      # org.freedesktop.DBus.Error.ServiceUnknown`).
                      stylix.autoEnable = false;
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
                    "withgraphite/homebrew-tap" = inputs.homebrew-graphite;
                    "nikitabobko/homebrew-tap" = inputs.homebrew-aerospace;
                    "theboredteam/homebrew-boring-notch" = inputs.homebrew-boring-notch;
                    "guria/homebrew-tap" = inputs.homebrew-nehir;
                    "jackielii/homebrew-tap" = inputs.homebrew-skhd-zig;
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
        headless = {
          modules = [
            inputs.disko.nixosModules.disko
            (
              { modulesPath, ... }:
              {
                imports = [
                  ../hosts/nixos/headless.nix
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
