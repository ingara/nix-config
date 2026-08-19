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
    [
      ../modules/shared/options.nix
      ../modules/shared/nixpkgs.nix
      {
        # Forward the whole system-scope myOptions tree to HM at mkDefault
        # priority (a per-HM override still wins). Both scopes import the
        # same options.nix, so this generically covers every leaf (theme,
        # user, dotfiles, ...) instead of a hand-enumerated list that
        # silently drops whichever option the list forgot.
        #
        # `windowManager.enabled` is a listOf, which merges/concatenates
        # instead of overriding by default, so it needs its own mkForce to
        # stay the single definition despite any stray HM-side definition
        # of the same list.
        myOptions = lib.mkMerge [
          (lib.mkDefault config.myOptions)
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

                  # Declarative tap trust. Homebrew 6.x enforces tap trust by
                  # default and refuses to load formulae/casks from non-official
                  # taps, which breaks `brew bundle` during activation. This lists
                  # exactly the items we install from non-official taps: graphite
                  # (withgraphite), skhd-zig (jackielii), plus the conditional
                  # WM-backend casks omniwm (barutsrb) / nehir (guria) / aerospace
                  # (nikitabobko) from `window-manager.nix` — all trusted so a
                  # backend switch or upgrade doesn't trip the gate.
                  #
                  # Currently INERT: the gate is disabled in
                  # `../modules/darwin/homebrew.nix` (brew's bundle deletes
                  # trust.json mid-activation, so per-item trust can't hold).
                  # Nothing enforces this list while the gate is off, so it can
                  # drift; re-enabling means re-auditing it against the
                  # non-official-tap items in `window-manager.nix` and the darwin
                  # `homebrew.casks`/`brews` first, not just flipping one line.
                  # (Entries aren't auto-removed when dropped here — `brew
                  # untrust` clears one.)
                  trust = {
                    formulae = [ "withgraphite/tap/graphite" ];
                    casks = [
                      "jackielii/tap/skhd-zig"
                      "barutsrb/tap/omniwm"
                      # Stable `nehir` declares conflicts_with the `nehir@rc`
                      # cask, so brew loads (and trust-checks) both even when
                      # only installing stable — trust both or the install is
                      # refused on the untrusted sibling.
                      "guria/tap/nehir"
                      "guria/tap/nehir@rc"
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
