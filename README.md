# nix-config

Multi-platform Nix configuration for macOS (nix-darwin) and NixOS.

## What's Included

- macOS configuration with Homebrew, AeroSpace WM, and sketchybar
- NixOS configuration
- Home Manager for dotfiles and user packages
- Global theming via Stylix (single `myOptions.theme.scheme` knob drives all
  surfaces)
- Reusable flake-parts modules for creating host configurations

## Platforms

| Platform              | Configuration                  |
| --------------------- | ------------------------------ |
| macOS (Apple Silicon) | declare via `easy-hosts.hosts` |
| NixOS                 | declare via `easy-hosts.hosts` |

This repo ships reusable modules, not runnable host configs. The example below
shows the minimum inputs for a NixOS-only consumer; macOS consumers must also
provide the Darwin, nix-homebrew, and Homebrew source inputs used by the
Darwin preset.

## Setup

Install Nix with flakes:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

Clone the repo:

```bash
git clone https://github.com/ingara/nix-config.git
cd nix-config
```

### Customization

Edit user identity in `modules/shared/options.nix` or override via your own
module:

```nix
myOptions.user = {
  username = "your-username";
  fullName = "Your Name";
  email = "your@email.com";
  signingKey = "ssh-key";
};
```

### macOS

Declare a darwin host through `easy-hosts.hosts` in your own flake, then:

```bash
nix build .#darwinConfigurations.<your-host>.system
./result/sw/bin/darwin-rebuild switch --flake .#<your-host>
```

Updates:

```bash
just switch
```

### NixOS

Declare a nixos host through `easy-hosts.hosts` in your own flake, then:

```bash
sudo nixos-rebuild switch --flake .#<your-host>
```

## Commands

```bash
just switch         # Apply changes (auto-detects platform)
just build          # Build without applying
just fmt            # Format nix files
just lint           # Lint with statix
just check          # Check for errors
just update         # Update flake inputs
just clean          # Remove artifacts and old generations
just dev            # Enter development shell
```

## Structure

- `flake.nix` — entry point (flake-parts + easy-hosts)
- `flake-modules/` — flake-parts modules (hosts, per-system, easy-hosts presets)
- `hosts/` — per-host configurations
- `modules/shared/` — cross-platform: options, theming, dotfiles, packages
  - `shared/system/` — NixOS/darwin system-level modules
  - `shared/home/` — home-manager program modules (git, fish, tmux, etc.)
- `modules/darwin/` — macOS-specific: homebrew, window manager, sketchybar
- `modules/nixos/` — NixOS system-level configuration
- `modules/linux/` — Linux home-manager base
- `modules/desktop/` — opt-in Linux desktop extras (GTK, polybar)
- `dotfiles/` — config files symlinked out-of-store for instant edits without
  rebuild
- `overlays/` — nixpkgs overlays (auto-imported)

## Using as a Library

This flake exports a `flakeModules.default` that you can import in your own
flake-parts-based flake:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    easy-hosts.url = "github:tgirlcloud/easy-hosts";
    home-manager.url = "github:nix-community/home-manager";
    disko.url = "github:nix-community/disko";
    stylix.url = "github:nix-community/stylix";
    public-config.url = "github:ingara/nix-config";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [
        inputs.easy-hosts.flakeModule
        inputs.public-config.flakeModules.default
      ];

      easy-hosts.hosts.myhost = {
        class = "nixos";
        arch = "x86_64";
        tags = [ "headless" ];
        path = ./hosts/myhost;
      };
    };
}
```

The flake module provides easy-hosts presets (`perClass.darwin`, `perClass.nixos`)
and shared Home Manager modules.
