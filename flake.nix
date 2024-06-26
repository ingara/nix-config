{
  description = "";
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
      url = "github:zhaofengli-wip/nix-homebrew";
    };
  };
  outputs = { self, darwin, nix-homebrew, home-manager, catppuccin, nixpkgs, disko, ... } @inputs:
    let
    user = "ingar";
    linuxSystems = [ "vboxnixos" ];
    darwinSystems = [ "aarch64-darwin" ];

    mkApp = scriptName: system: {
      type = "app";
      program = "${(nixpkgs.legacyPackages.${system}.writeScriptBin scriptName ''
        #!/usr/bin/env bash
        PATH=${nixpkgs.legacyPackages.${system}.git}/bin:$PATH
        echo "Running '${scriptName}' for '${system}' with args: $@"
        exec ${self}/apps/${system}/${scriptName} $@
      '')}/bin/${scriptName}";
    };
    mkLinuxApps = system: {};
    mkDarwinApps = system: {
      # "apply" = mkApp "apply" system;
      "build" = mkApp "build" system;
      "build-switch" = mkApp "build-switch" system;
      # "copy-keys" = mkApp "copy-keys" system;
      # "create-keys" = mkApp "create-keys" system;
      # "check-keys" = mkApp "check-keys" system;
      # "rollback" = mkApp "rollback" system;
    };
  in {
    apps = nixpkgs.lib.genAttrs linuxSystems mkLinuxApps // nixpkgs.lib.genAttrs darwinSystems mkDarwinApps;

    darwinConfigurations = nixpkgs.lib.genAttrs darwinSystems (system:
        darwin.lib.darwinSystem {
          inherit system;
          # system = "aarch64-darwin";
          specialArgs = inputs;
          modules = [
            home-manager.darwinModules.home-manager
            # catppuccin.darwinModules.catppuccin
            nix-homebrew.darwinModules.nix-homebrew
            {
              nix-homebrew = {
                inherit user;
                enable = true;
                enableRosetta = true;
                # taps = with inputs; {
                #   "homebrew/homebrew-core" = homebrew-core;
                #   "homebrew/homebrew-cask" = homebrew-cask;
                #   "homebrew/homebrew-bundle" = homebrew-bundle;
                #   "homebrew/homebrew-services" = homebrew-services;
                #   "koekeishiya/homebrew-formulae" = koekeishiya;
                #   "FelixKratz/homebrew-formulae" = FelixKratz;
                # };
                mutableTaps = true;
              };
            }
            ./hosts/darwin
          ];
        }
    );

    nixosConfigurations = nixpkgs.lib.genAttrs linuxSystems (system:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = inputs;
        modules = [
          disko.nixosModules.disko
          catppuccin.nixosModules.catppuccin
          home-manager.nixosModules.home-manager {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.${user} = {
                imports = [
                  ./modules/nixos/home-manager.nix
                  catppuccin.homeManagerModules.catppuccin
                ];
              };
            };
          }
          ./hosts/nixos
        ];
      }
    );
  };
}
