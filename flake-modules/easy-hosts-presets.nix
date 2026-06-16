# easy-hosts presets — the module lists previously hidden inside
# mkDarwinHost / mkNixosHost / mkHeadlessServer builder functions.
#
# Organization:
#   - easy-hosts.shared.modules     → every host (options.nix is the myOptions schema)
#   - easy-hosts.perClass.nixos     → every nixos host
#   - easy-hosts.perClass.darwin    → every darwin host
#   - easy-hosts.perTag.server      → headless servers (disko + qemu-guest + base.nix)
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
                    { config, ... }:
                    {
                      imports = [
                        ../modules/linux/home-manager.nix
                        inputs.stylix.homeModules.stylix
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
                      stylix = {
                        enable = true;
                        autoEnable = false;
                        # Stylix and home-manager both track master, so their
                        # release strings never match and the version check is
                        # a permanent false positive. It gates a warning only,
                        # not behaviour; a real incompatibility still errors.
                        enableReleaseChecks = false;
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

                  # Declarative tap trust. Homebrew 6.x enforces tap trust by
                  # default and refuses to load formulae/casks from non-official
                  # taps, which breaks `brew bundle` during activation. We trust
                  # exactly the items we install from non-official taps, rather
                  # than blanket-disabling trust enforcement. (Replaced the
                  # interim `extraEnv.HOMEBREW_NO_REQUIRE_TAP_TRUST = "1"` opt-out
                  # once nix-homebrew shipped per-item trust —
                  # zhaofengli/nix-homebrew PR #157.)
                  #
                  # Keep this in sync with every non-official-tap item the
                  # config can install: graphite (withgraphite), skhd-zig
                  # (jackielii), plus the two conditional WM-backend casks
                  # omniwm (barutsrb) / aerospace (nikitabobko) from
                  # `window-manager.nix` — trusted unconditionally so a backend
                  # switch or an upgrade of either doesn't trip the trust gate.
                  #
                  # Note: trust entries are NOT auto-removed when dropped from
                  # these lists — use `brew untrust` to clear one.
                  trust = {
                    formulae = [ "withgraphite/tap/graphite" ];
                    casks = [
                      "jackielii/tap/skhd-zig"
                      "barutsrb/tap/omniwm"
                      "nikitabobko/tap/aerospace"
                    ];
                  };

                  taps = {
                    "homebrew/homebrew-core" = inputs.homebrew-core;
                    "homebrew/homebrew-cask" = inputs.homebrew-cask;
                    "homebrew/homebrew-bundle" = inputs.homebrew-bundle;
                    "felixkratz/homebrew-formulae" = inputs.homebrew-felixkratz;
                    "withgraphite/homebrew-tap" = inputs.homebrew-graphite;
                    "nikitabobko/homebrew-tap" = inputs.homebrew-aerospace;
                    "theboredteam/homebrew-boring-notch" = inputs.homebrew-boring-notch;
                    "BarutSRB/homebrew-tap" = inputs.homebrew-omniwm;
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
