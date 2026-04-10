{
  description = "Multi-platform Nix configuration (macOS, NixOS, Fedora)";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
    };

    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };

    homebrew-felixkratz = {
      url = "github:FelixKratz/homebrew-formulae";
      flake = false;
    };
    homebrew-satococoa = {
      url = "github:satococoa/homebrew-tap";
      flake = false;
    };
    homebrew-graphite = {
      url = "github:withgraphite/homebrew-tap";
      flake = false;
    };
    homebrew-aerospace = {
      url = "github:nikitabobko/homebrew-tap";
      flake = false;
    };
    homebrew-boring-notch = {
      url = "github:TheBoredTeam/homebrew-boring-notch";
      flake = false;
    };
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-flatpak = {
      url = "github:gmodena/nix-flatpak";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    claude-code-nix = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    aerospace-scratchpad = {
      url = "github:cristianoliveira/aerospace-scratchpad";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      self,
      darwin,
      nix-homebrew,
      home-manager,
      catppuccin,
      nixpkgs,
      disko,
      nixos-wsl,
      treefmt-nix,
      ...
    }@inputs:
    let
      supportedSystems = [
        "aarch64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      forEachSystem = nixpkgs.lib.genAttrs supportedSystems;
      treefmtEval = forEachSystem (
        system: treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} ./treefmt.nix
      );

      # Propagate system-level myOptions to home-manager
      mkSharedModules =
        { config, lib }:
        [
          ./modules/shared/options.nix
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
            };
          }
        ];

      mkNixosHost =
        {
          system ? "x86_64-linux",
          hostPath,
          hmImports ? [ ],
          extraModules ? [ ],
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
          };
          modules = [
            ./modules/shared/options.nix
            {
              myOptions.dotfiles.repoRoot = "/home/user/nix-config";
            }
            catppuccin.nixosModules.catppuccin
            home-manager.nixosModules.home-manager
            (
              { config, lib, ... }:
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  sharedModules = mkSharedModules { inherit config lib; };
                  users.${config.myOptions.user.username} = {
                    imports = [
                      ./modules/linux/home-manager.nix
                      catppuccin.homeModules.catppuccin
                    ]
                    ++ hmImports;
                  };
                };
              }
            )
            hostPath
          ]
          ++ extraModules;
        };

      mkHeadlessServer =
        {
          hostPath,
          extraModules ? [ ],
          hmImports ? [ ],
        }:
        mkNixosHost {
          system = "aarch64-linux";
          inherit hostPath;
          extraModules = [
            disko.nixosModules.disko
            (
              { modulesPath, ... }:
              {
                imports = [
                  ./hosts/nixos/base.nix
                  (modulesPath + "/profiles/qemu-guest.nix")
                ];
              }
            )
          ]
          ++ extraModules;
          inherit hmImports;
        };

      mkDarwinHost =
        {
          extraModules ? [ ],
          hmImports ? [ ],
        }:
        darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = {
            inherit inputs;
          };
          modules = [
            ./modules/shared/options.nix
            {
              myOptions.dotfiles.repoRoot = "/Users/user/nix-config";
            }
            home-manager.darwinModules.home-manager
            nix-homebrew.darwinModules.nix-homebrew
            (
              { config, ... }:
              {
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
                  };
                };
              }
            )
            # Inject hmImports via sharedModules so they reach home-manager users
            (
              { config, lib, ... }:
              {
                home-manager.sharedModules = mkSharedModules { inherit config lib; } ++ hmImports;
              }
            )
            ./hosts/darwin
          ]
          ++ extraModules;
        };

      mkFedoraHome =
        {
          extraModules ? [ ],
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = {
            inherit inputs;
          };
          modules = [
            ./modules/shared/options.nix
            {
              myOptions.hasGui = true;
              myOptions.dotfiles.repoRoot = "/home/user/nix-config";
            }
            ./hosts/fedora
          ]
          ++ extraModules;
        };
    in
    {
      lib = {
        inherit
          mkNixosHost
          mkHeadlessServer
          mkDarwinHost
          mkFedoraHome
          ;
      };

      devShells = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              nixfmt
              statix
              just
              git
              bash
              lefthook
            ];

            shellHook = ''
              echo "🚀 Nix config development environment loaded!"
              just
            '';
          };
        }
      );

      # `nix fmt` entrypoint — runs treefmt with all formatters + linters.
      formatter = forEachSystem (system: treefmtEval.${system}.config.build.wrapper);

      # `nix flake check` validates formatting.
      checks = forEachSystem (system: {
        formatting = treefmtEval.${system}.config.build.check self;
      });

      # Standalone configurations with placeholder identity
      darwinConfigurations.scadrial = mkDarwinHost { };

      nixosConfigurations = {
        vboxnixos = mkNixosHost {
          hostPath = ./hosts/nixos/vbox;
          hmImports = [
            ./modules/desktop
            ./modules/desktop/gtk.nix
            ./modules/desktop/polybar.nix
          ];
          extraModules = [ disko.nixosModules.disko ];
        };

        wsl = mkNixosHost {
          hostPath = ./hosts/nixos/wsl;
          extraModules = [ nixos-wsl.nixosModules.wsl ];
        };
      };

      homeConfigurations = {
        komashi = mkFedoraHome { };
      };
    };
}
