{
  description = "Multi-platform Nix configuration (macOS, NixOS, Fedora)";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
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
    homebrew-services = {
      url = "github:homebrew/homebrew-services";
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
    nh = {
      url = "github:nix-community/nh";
      inputs.nixpkgs.follows = "nixpkgs";
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
      ...
    }@inputs:
    let
      userConfig = {
        username = "ingar";
        fullName = "Ingar Mathisen Almklov";
        email = "ingara@gmail.com";
        signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF2vZOGuH6Eix++BVA093FnJvrjSa1aLa5v976xVsp5K";
      };

      user = userConfig.username;

      mkNixosHost =
        {
          system ? "x86_64-linux",
          hasGui,
          hostPath,
          hmImports ? [ ],
          mkSshSignProgram ? (_pkgs: null),
          extraModules ? [ ],
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = inputs // {
            inherit userConfig hasGui;
          };
          modules = [
            catppuccin.nixosModules.catppuccin
            home-manager.nixosModules.home-manager
            (
              { pkgs, ... }:
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  users.${user} = {
                    imports = [
                      ./modules/linux/home-manager.nix
                      catppuccin.homeModules.catppuccin
                    ] ++ hmImports;
                  };
                  extraSpecialArgs = {
                    inherit userConfig hasGui;
                    sshSignProgram = mkSshSignProgram pkgs;
                  };
                };
              }
            )
            hostPath
          ] ++ extraModules;
        };
    in
    {
      devShells = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-linux" ] (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              nixfmt-rfc-style # RFC 166 nix formatter
              statix # Nix linter and suggestions
              just # Command runner
              git
              bash # For justfile shebang recipes
            ];

            shellHook = ''
              echo "🚀 Nix config development environment loaded!"
              just
            '';
          };
        }
      );

      darwinConfigurations.scadrial = darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = inputs // {
          inherit userConfig;
          hasGui = true;
        };
        modules = [
          home-manager.darwinModules.home-manager
          nix-homebrew.darwinModules.nix-homebrew
          {
            nix-homebrew = {
              inherit user;
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
          ./hosts/darwin
        ];
      };

      nixosConfigurations = {
        vboxnixos = mkNixosHost {
          hasGui = true;
          hostPath = ./hosts/nixos/vbox;
          hmImports = [
            ./modules/desktop
            ./modules/desktop/gtk.nix
            ./modules/desktop/polybar.nix
          ];
          mkSshSignProgram = pkgs: "${pkgs._1password-gui}/bin/op-ssh-sign";
          extraModules = [ disko.nixosModules.disko ];
        };

        wsl = mkNixosHost {
          hasGui = false;
          hostPath = ./hosts/nixos/wsl;
          extraModules = [ nixos-wsl.nixosModules.wsl ];
        };
      };

      homeConfigurations = {
        komashi = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = inputs // {
            inherit userConfig;
            hasGui = true;
          };
          modules = [ ./hosts/fedora ];
        };
      };
    };
}
