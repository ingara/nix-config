{
  description = "Multi-platform Nix configuration (macOS, NixOS, Fedora)";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    import-tree.url = "github:denful/import-tree";
    easy-hosts.url = "github:tgirlcloud/easy-hosts";
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
      # Note: nix-homebrew declares no nixpkgs input, so no `follows` needed
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
    homebrew-omniwm = {
      url = "github:BarutSRB/homebrew-tap";
      flake = false;
    };
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-flatpak = {
      # Note: nix-flatpak declares no inputs at all, so no `follows` needed
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
    # opencode iterates faster than nixos-unstable's Hydra cadence — the
    # channel routinely trails upstream by 1–2 weeks. Pin the input here
    # so `just update` bumps opencode to whatever upstream's `dev` branch
    # tags. Upstream maintains the Nix derivation (`nix/opencode.nix`)
    # and pins node_modules by FOD hash. Built from source locally
    # (~30s–1m, Bun build). Consumed in `modules/shared/home/ai/opencode.nix`.
    opencode = {
      url = "github:sst/opencode";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];

      imports = [
        inputs.easy-hosts.flakeModule
        (inputs.import-tree ./flake-modules)
      ];
    };
}
