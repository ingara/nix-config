# nix-config

Multi-platform Nix configuration for macOS (nix-darwin), NixOS (VirtualBox +
WSL), and Fedora (home-manager only).

## What's Included

- macOS configuration with Homebrew, AeroSpace WM, and sketchybar
- NixOS configurations for VirtualBox and WSL
- Fedora configuration with KDE Plasma via plasma-manager
- Home Manager for dotfiles and user packages
- Catppuccin theming across all platforms
- Reusable builder functions for creating host configurations

## Platforms

| Platform              | Configuration |
| --------------------- | ------------- |
| macOS (Apple Silicon) | `scadrial`    |
| NixOS VirtualBox      | `vboxnixos`   |
| NixOS WSL             | `wsl`         |
| Fedora                | `komashi`     |

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

Install nix-darwin:

```bash
nix build .#darwinConfigurations.scadrial.system
./result/sw/bin/darwin-rebuild switch --flake .#scadrial
```

Updates:

```bash
just switch
```

### NixOS WSL

Install [NixOS-WSL](https://github.com/nix-community/NixOS-WSL) first, then:

```bash
git clone https://github.com/ingara/nix-config.git ~/nix-config
cd ~/nix-config
sudo nixos-rebuild switch --flake .#wsl
```

### NixOS VirtualBox

```bash
git clone https://github.com/ingara/nix-config.git ~/nix-config
cd ~/nix-config
sudo nixos-rebuild switch --flake .#vboxnixos
```

### Fedora

Requires Nix installed on an existing Fedora system with KDE Plasma:

```bash
git clone https://github.com/ingara/nix-config.git ~/nix-config
cd ~/nix-config
nix run home-manager -- switch --flake .#komashi
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

- `flake.nix` — entry point with builder functions and host definitions
- `hosts/` — per-host configurations
- `modules/shared/` — cross-platform packages, programs, dotfiles
- `modules/darwin/` — macOS-specific: homebrew, window manager, sketchybar
- `modules/nixos/` — NixOS system-level configuration
- `modules/linux/` — Linux home-manager base
- `modules/desktop/` — opt-in Linux desktop extras (GTK, polybar)
- `dotfiles/` — config files symlinked out-of-store for instant edits without
  rebuild

## Using as a Library

This flake exports builder functions that you can use from your own private
flake:

```nix
let
  publicFlake = (import ./public/flake.nix).outputs ((import ./public/flake.nix).inputs // inputs);
in {
  darwinConfigurations.myhost = publicFlake.lib.mkDarwinHost {
    hmImports = [ ./my-home-config.nix ];
    extraModules = [ ./my-system-config.nix ];
  };
}
```

Available builders: `mkDarwinHost`, `mkNixosHost`, `mkHeadlessServer`,
`mkFedoraHome`.
