# nix-config

Multi-platform Nix flake managing macOS (nix-darwin), NixOS (WSL + VirtualBox), and Fedora (home-manager only). All Nix files use `nixpkgs-unstable`. Format with `nixfmt-rfc-style`, lint with `statix`.

## Structure

- `flake.nix` — entry point, defines all hosts and a dev shell
- `hosts/` — per-host configs
- `modules/shared/` — cross-platform: packages, home-manager programs, dotfile symlinks
- `modules/darwin/` — macOS: homebrew casks/brews, window manager toggle, sketchybar
- `modules/nixos/` — NixOS: disko, 1password
- `dotfiles/` — config files (nvim, wezterm, tmux, etc.) managed as `mkOutOfStoreSymlink` links, not Nix store paths. This means dotfile edits take effect immediately without a rebuild. The symlink wiring is in `modules/shared/dotfiles.nix`.
- `justfile` — build/switch/update commands, auto-detects current platform

## Hosts

| Host | Platform | Type | Notes |
|---|---|---|---|
| `aarch64-darwin` | macOS Apple Silicon | nix-darwin | AeroSpace WM (switchable), sketchybar, Homebrew casks |
| `wsl` | NixOS on WSL | NixOS system | Hostname `nixos-wsl`, Windows interop disabled |
| `vboxnixos` | NixOS on VirtualBox | NixOS system | GNOME 3, disko disk management |
| `komashi` | Fedora | home-manager only | KDE Plasma via plasma-manager, Flatpak apps |

## Commands

Build and apply: `just switch` (auto-detects platform). Format: `just fmt`. Lint: `just lint`. Update all inputs: `just update`.
