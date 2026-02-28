# nix-config

Multi-platform Nix flake managing macOS (nix-darwin), NixOS (WSL + VirtualBox), and Fedora (home-manager only). All Nix files use `nixpkgs-unstable`. Format with `nixfmt-rfc-style`, lint with `statix`.

## Structure

- `flake.nix` — entry point, defines all hosts and a dev shell. Each host sets `hasGui` and optionally `sshSignProgram` via `specialArgs`/`extraSpecialArgs`.
- `hosts/` — per-host configs (hardware, boot, networking, host-specific services)
- `modules/shared/` — cross-platform: packages, home-manager programs, dotfile symlinks
- `modules/darwin/` — macOS: homebrew casks/brews, window manager toggle, sketchybar
- `modules/nixos/` — NixOS system-level only: 1password NixOS module, disko
- `modules/linux/` — Linux home-manager entry point (used by NixOS hosts; Fedora composes shared modules directly)
- `modules/desktop/` — opt-in Linux desktop HM extras: `default.nix` (core packages), `gtk.nix`, `polybar.nix` (import per-host as needed)
- `dotfiles/` — config files (nvim, wezterm, tmux, etc.) managed as `mkOutOfStoreSymlink` links, not Nix store paths. This means dotfile edits take effect immediately without a rebuild. The symlink wiring is in `modules/shared/dotfiles.nix`.
- `justfile` — build/switch/update commands, auto-detects current platform

## Hosts

| Host | Platform | Type | Notes |
|---|---|---|---|
| `scadrial` | macOS Apple Silicon | nix-darwin | AeroSpace WM (switchable), sketchybar, Homebrew casks |
| `wsl` | NixOS on WSL | NixOS system | Hostname `nixos-wsl`, Windows interop disabled |
| `vboxnixos` | NixOS on VirtualBox | NixOS system | GNOME 3, disko disk management |
| `komashi` | Fedora | home-manager only | KDE Plasma via plasma-manager, Flatpak apps |

## Commands

Build and apply: `just switch` (auto-detects platform). Format: `just fmt`. Lint: `just lint`. Update all inputs: `just update`.
