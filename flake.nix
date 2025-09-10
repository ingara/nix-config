{
  description = "Personal macOS development environment with nix-darwin and home-manager";
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
    # Nice theme
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
    nh = {
      url = "github:nix-community/nh";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
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
      nh,
      nixos-wsl,
      ...
    }@inputs:
    let
      # Centralized user configuration
      userConfig = {
        username = "ingar";
        fullName = "Ingar Mathisen Almklov";
        email = "ingara@gmail.com";
        signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF2vZOGuH6Eix++BVA093FnJvrjSa1aLa5v976xVsp5K";
      };

      # Legacy alias for compatibility
      user = userConfig.username;

      # System architectures for apps
      linuxSystems = [ "x86_64-linux" ];
      darwinSystems = [ "aarch64-darwin" ];

      # Configuration names
      nixosHosts = [
        "vboxnixos"
        "wsl"
      ];
      darwinHosts = [ "aarch64-darwin" ];

      mkApp = scriptName: system: {
        type = "app";
        program = "${
          (nixpkgs.legacyPackages.${system}.writeScriptBin scriptName ''
            #!/usr/bin/env bash
            PATH=${nixpkgs.legacyPackages.${system}.git}/bin:$PATH
            echo "Running '${scriptName}' for '${system}' with args: $@"
            exec ${self}/apps/${system}/${scriptName} $@
          '')
        }/bin/${scriptName}";
        meta = {
          description = "Build script for ${scriptName}";
        };
      };
      mkLinuxApps = system: { };
      mkDarwinApps = system: {
        # "apply" = mkApp "apply" system;
        "build" = mkApp "build" system;
        "build-switch" = mkApp "build-switch" system;
        # nh-switch has different implementation than mkApp pattern because it needs
        # the 'nh' binary in PATH, unlike other apps that only need git
        "nh-switch" = {
          type = "app";
          program = "${
            (nixpkgs.legacyPackages.${system}.writeScriptBin "nh-switch" ''
              #!/usr/bin/env bash
              PATH=${nh.packages.${system}.default}/bin:${nixpkgs.legacyPackages.${system}.git}/bin:$PATH
              echo "Running 'nh-switch' for '${system}' with args: $@"
              exec ${self}/apps/${system}/nh-switch $@
            '')
          }/bin/nh-switch";
          meta = {
            description = "NixOS system switching using nh";
          };
        };
        # "copy-keys" = mkApp "copy-keys" system;
        # "create-keys" = mkApp "create-keys" system;
        # "check-keys" = mkApp "check-keys" system;
        # "rollback" = mkApp "rollback" system;
      };
    in
    {
      # Development shell with formatting tools
      devShells = nixpkgs.lib.genAttrs (darwinSystems ++ linuxSystems) (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              nixfmt-rfc-style # RFC 166 nix formatter
              just # Command runner
              git
              bash # For justfile shebang recipes
            ];

            shellHook = ''
              echo "🚀 Nix config development environment loaded!"
              echo "Available commands:"
              echo "  just fmt     - Format all nix files with nixfmt-rfc-style"
              echo "  just check   - Run nix flake check"
              echo "  just switch  - Switch to new configuration" 
              echo "  just build   - Build configuration"
            '';
          };
        }
      );

      apps =
        nixpkgs.lib.genAttrs linuxSystems mkLinuxApps // nixpkgs.lib.genAttrs darwinSystems mkDarwinApps;

      darwinConfigurations = nixpkgs.lib.genAttrs darwinHosts (
        hostname:
        let
          system = "aarch64-darwin";
        in
        darwin.lib.darwinSystem {
          inherit system;
          specialArgs = inputs // {
            inherit userConfig;
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
                };
              };
            }
            ./hosts/darwin
          ];
        }
      );

      nixosConfigurations = {
        vboxnixos = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = inputs // {
            inherit userConfig;
          };
          modules = [
            disko.nixosModules.disko
            catppuccin.nixosModules.catppuccin
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.${user} = {
                  imports = [
                    ./modules/nixos/home-manager.nix
                    catppuccin.homeModules.catppuccin
                  ];
                };
                extraSpecialArgs = {
                  inherit userConfig;
                };
              };
            }
            ./hosts/nixos/vbox
          ];
        };

        wsl = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = inputs // {
            inherit userConfig;
          };
          modules = [
            nixos-wsl.nixosModules.wsl
            catppuccin.nixosModules.catppuccin
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.${user} = {
                  imports = [
                    ./modules/nixos/home-manager.nix
                    catppuccin.homeModules.catppuccin
                  ];
                };
                extraSpecialArgs = {
                  inherit userConfig;
                };
              };
            }
            ./hosts/nixos/wsl
          ];
        };
      };
    };
}
