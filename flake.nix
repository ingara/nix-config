{
  description = "Multi-platform Nix configuration (macOS, NixOS)";
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
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tinted-schemes = {
      url = "github:tinted-theming/schemes";
      flake = false;
    };
    nix-homebrew = {
      # Note: nix-homebrew declares no nixpkgs input, so no nixpkgs `follows` needed
      url = "github:zhaofengli/nix-homebrew";
      inputs.brew-src.follows = "brew-src";
    };
    # The cask tap uses DSL newer than nix-homebrew's bundled brew can parse:
    # `zap :not_required` needs brew >= 7.0.11 (Homebrew/brew#24315).
    # REMOVE WHEN nix-homebrew's own brew-src is >= 7.0.11; check with
    # `nix flake metadata github:zhaofengli/nix-homebrew --json | jq -r '.locks.nodes."brew-src".original.ref'`.
    # Bump this to the latest Homebrew release whenever the homebrew taps are bumped.
    brew-src = {
      url = "github:Homebrew/brew/7.0.11";
      flake = false;
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

    homebrew-graphite = {
      url = "github:withgraphite/homebrew-tap";
      flake = false;
    };
    homebrew-aerospace = {
      url = "github:nikitabobko/homebrew-tap";
      flake = false;
    };
    homebrew-skhd-zig = {
      url = "github:jackielii/homebrew-tap";
      flake = false;
    };
    claude-code-nix = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    codex-cli-nix = {
      url = "github:sadjow/codex-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # numtide's AI-agent package set; we consume only its prebuilt
    # `packages.<system>.opencode`. `follows` nixpkgs, and since the derivation
    # is fetchurl + autoPatchelf + wrapper with no compilation, it needs no
    # binary cache.
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lavish-axi = {
      url = "github:kunchenguid/lavish-axi/lavish-axi-v0.1.93";
      flake = false;
    };
    aerospace-scratchpad = {
      url = "github:cristianoliveira/aerospace-scratchpad";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    paneru = {
      url = "github:karinushka/paneru";
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
