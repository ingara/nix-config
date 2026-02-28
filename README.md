# Personal Nix Configuration

Nix configuration for macOS (nix-darwin), NixOS (VirtualBox + WSL), and Fedora (home-manager only).

## What's included

- macOS configuration with Homebrew, AeroSpace WM, and sketchybar
- NixOS configurations for VirtualBox and WSL
- Fedora configuration with KDE Plasma via plasma-manager
- Home Manager for dotfiles and user packages
- Catppuccin theming across all platforms
- Development tools and CLI utilities

## Platforms

| Platform | Configuration |
|----------|---------------|
| macOS (Apple Silicon) | `scadrial` |
| NixOS VirtualBox | `vboxnixos` |
| NixOS WSL | `wsl` |
| Fedora | `komashi` |

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

Install [NixOS-WSL](https://github.com/nix-community/NixOS-WSL) first.

Initial setup (as `nixos` user):

```bash
# Clone and apply config (creates "ingar" user)
nix-shell -p git --run "sudo git clone https://github.com/ingar/nix-config.git /etc/nixos/nix-config"
cd /etc/nixos/nix-config
sudo nixos-rebuild switch --flake .#wsl
```

After WSL restart (now logged in as `ingar`):

```bash
# Move config to home directory and take ownership
sudo mv /etc/nixos/nix-config ~/nix-config
sudo chown -R ingar:users ~/nix-config
```

Updates:

```bash
cd ~/nix-config
just switch
```

### NixOS VirtualBox

Install NixOS in VirtualBox.

Apply config:

```bash
git clone https://github.com/ingar/nix-config.git ~/nix-config
cd ~/nix-config
sudo nixos-rebuild switch --flake .#vboxnixos
```

Updates:

```bash
cd ~/nix-config
just switch
```

### Fedora

Requires Nix installed on an existing Fedora system with KDE Plasma.

Apply config:

```bash
git clone https://github.com/ingara/nix-config.git ~/nix-config
cd ~/nix-config
nix run home-manager -- switch --flake .#komashi
```

Updates:

```bash
cd ~/nix-config
just switch
```

## Commands

Available commands (work on all platforms):

```bash
just dev            # Development shell
just fmt            # Format nix files
just check          # Check for errors
just build          # Build config
just switch         # Apply changes
just clean          # Remove artifacts
just update         # Update inputs
```

Platform-specific builds:

```bash
just build-darwin   # macOS
just build-wsl      # WSL
just build-vbox     # VirtualBox
just build-fedora   # Fedora
just switch-fedora  # Fedora (switch only)
```

Run commands from your config directory (`~/nix-config`).

## Structure

Modules are split by platform: `modules/shared/` (cross-platform packages, programs, dotfiles), `modules/darwin/` (macOS-specific: homebrew, WM, sketchybar), `modules/nixos/` (NixOS system-level), `modules/linux/` (Linux home-manager base), and `modules/desktop/` (opt-in Linux desktop extras like GTK and polybar). Per-host configs live under `hosts/`. Dotfiles are symlinked out-of-store for instant edits without rebuild.

## Customization

Edit user info in `flake.nix`:

```nix
userConfig = {
  username = "your-username";
  fullName = "Your Name";
  email = "your@email.com";
  signingKey = "ssh-key";
};
```

Add packages:

- Cross-platform: `modules/shared/packages.nix`
- macOS only: `modules/darwin/packages.nix`
- macOS apps (Homebrew): `modules/darwin/homebrew.nix`
