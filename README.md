# nix-config

Multi-platform Nix configuration for macOS (nix-darwin), NixOS (VirtualBox),
and Fedora (home-manager only).

## What's Included

- macOS configuration with Homebrew, AeroSpace WM, and sketchybar
- NixOS configuration for VirtualBox
- Fedora configuration with KDE Plasma via plasma-manager
- Home Manager for dotfiles and user packages
- Global theming via Stylix (single `myOptions.theme.scheme` knob drives all
  surfaces)
- Reusable flake-parts modules and builder functions for creating host
  configurations

## Platforms

| Platform              | Configuration                 |
| --------------------- | ----------------------------- |
| macOS (Apple Silicon) | build via `mkDarwinHost`      |
| NixOS VirtualBox      | `vboxnixos` (runnable sample) |
| Fedora                | build via `mkFedoraHome`      |

The runnable sample config is `vboxnixos`. Darwin and Fedora/home-manager
hosts are built from the exported builder functions in your own flake — this
repo ships the reusable modules and builders, not personal host configs.

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

Define a darwin host with the `mkDarwinHost` builder in your own flake, then:

```bash
nix build .#darwinConfigurations.<your-host>.system
./result/sw/bin/darwin-rebuild switch --flake .#<your-host>
```

Updates:

```bash
just switch
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
nix run home-manager -- switch --flake .#<your-host>
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
  inputs.public-config.url = "path:./public"; # or github:ingara/nix-config

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.public-config.flakeModules.default ];

      # Declare hosts via easy-hosts
      easy-hosts.hosts.myhost = {
        class = "darwin";
        # ...
      };
    };
}
```

The flake module provides easy-hosts presets (`perClass.darwin`, `perClass.nixos`,
shared HM modules), and exports `flake.lib.mkFedoraHome` for standalone
home-manager configurations.
