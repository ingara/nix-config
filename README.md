# Personal Nix Configuration

Nix configuration for macOS (nix-darwin) and NixOS (including WSL).

## What's included

- macOS configuration with Homebrew
- NixOS configurations for VirtualBox and WSL
- Home Manager for dotfiles and user packages
- Catppuccin theming
- Development tools and CLI utilities

## Platforms

| Platform | Configuration |
|----------|---------------|
| macOS (Apple Silicon) | `aarch64-darwin` |
| NixOS WSL | `wsl` |
| NixOS VirtualBox | `vboxnixos` |

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
nix build .#darwinConfigurations.aarch64-darwin.system
./result/sw/bin/darwin-rebuild switch --flake .
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
sudo nixos-rebuild switch --flake .#wsl
# or: just switch
```

### NixOS VirtualBox

Install NixOS in VirtualBox.

Apply config:
```bash
# Clone to home directory
git clone https://github.com/ingar/nix-config.git ~/nix-config
cd ~/nix-config

# Edit username in flake.nix if needed (default is "ingar")  
sudo nixos-rebuild switch --flake .#vboxnixos
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
```

Run commands from your config directory (`~/nix-config` on NixOS, `./nix-config` on macOS).

## Structure

```
├── flake.nix          # Main config
├── justfile           # Commands
├── hosts/             # Platform configs
├── modules/           # Nix modules
├── dotfiles/          # Config files
└── apps/              # Build scripts
```

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
- System: `modules/{platform}/packages.nix`
- User: `modules/shared/packages.nix`
- macOS apps: `modules/darwin/homebrew.nix`
