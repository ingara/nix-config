# Nix configuration development tasks
set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

# Format all nix files with nixfmt-rfc-style
fmt:
    find . -name "*.nix" -type f -exec nixfmt {} \;

# Check nix configuration for errors
check:
    nix flake check

# Build configuration (auto-detects platform)
build:
    @if [ "{{os()}}" = "macos" ]; then \
        nix build .#darwinConfigurations.scadrial.system; \
    elif [ -f /proc/version ] && grep -qi microsoft /proc/version; then \
        nix build .#nixosConfigurations.wsl.config.system.build.toplevel; \
    elif [ -f /etc/fedora-release ]; then \
        nix build .#homeConfigurations.komashi.activationPackage; \
    else \
        nix build .#nixosConfigurations.vboxnixos.config.system.build.toplevel; \
    fi

# Switch to new configuration (auto-detects platform)
switch *ARGS:
    @if [ "{{os()}}" = "macos" ]; then \
        printf "\033[1;33mStarting darwin switch...\033[0m\n"; \
        export NIXPKGS_ALLOW_UNFREE=1; \
        nh darwin switch -H scadrial . {{ARGS}}; \
        WM_BACKEND=$(grep -o 'myOptions.windowManager.backend = "[^"]*"' hosts/darwin/default.nix | cut -d'"' -f2); \
        if [ "$WM_BACKEND" = "yabai" ]; then \
            printf "\033[1;33mLoading yabai scripting addition...\033[0m\n"; \
            sudo yabai --load-sa 2>/dev/null && \
                printf "\033[1;32mYabai scripting addition loaded!\033[0m\n" || \
                printf "\033[1;31mYabai scripting addition failed (not supported on macOS Tahoe yet)\033[0m\n"; \
        fi; \
        printf "\033[1;32mSwitch to new generation complete!\033[0m\n"; \
    elif [ -f /proc/version ] && grep -qi microsoft /proc/version; then \
        printf "\033[1;33mStarting NixOS WSL switch...\033[0m\n"; \
        nh os switch --hostname wsl . {{ARGS}}; \
        printf "\033[1;32mNixOS WSL switch complete!\033[0m\n"; \
    elif [ -f /etc/fedora-release ]; then \
        printf "\033[1;33mStarting Fedora home-manager switch...\033[0m\n"; \
        nix run home-manager -- switch --flake .#komashi {{ARGS}}; \
        printf "\033[1;32mFedora home-manager switch complete!\033[0m\n"; \
    else \
        printf "\033[1;33mStarting NixOS switch...\033[0m\n"; \
        nh os switch --hostname vboxnixos . {{ARGS}}; \
        printf "\033[1;32mNixOS switch complete!\033[0m\n"; \
    fi

# Build specific configuration
build-darwin:
    nix build .#darwinConfigurations.scadrial.system

build-wsl:
    nix build .#nixosConfigurations.wsl.config.system.build.toplevel

build-vbox:
    nix build .#nixosConfigurations.vboxnixos.config.system.build.toplevel

build-fedora:
    nix build .#homeConfigurations.komashi.activationPackage

switch-fedora *ARGS:
    nix run home-manager -- switch --flake .#komashi {{ARGS}}

# Enter development shell with tools
dev:
    nix develop

# Clean up build artifacts and old generations
clean:
    rm -f result*
    nh clean all --keep 5
    nix-collect-garbage -d

# Show flake info
info:
    nix flake info

# Update all dependencies (nix flake + homebrew if available)
update:
    @just update-nix
    @command -v brew >/dev/null 2>&1 && just update-brew || true
    @command -v flatpak >/dev/null 2>&1 && just update-flatpak || true

# Update nix flake inputs
update-nix:
    nix flake update

# Upgrade all homebrew packages (taps are updated via nix flake update)
update-brew:
    brew upgrade && brew cleanup

# Update all flatpak packages
update-flatpak:
    flatpak update -y

# Format check (don't format, just check)
fmt-check:
    find . -name "*.nix" -type f -exec nixfmt --check {} \;

# Lint nix files with statix
lint:
    statix check .

# Auto-fix linting issues with statix
lint-fix:
    statix fix .

# Restart yabai window manager
restart-yabai:
    launchctl kickstart -k gui/$(id -u)/org.nixos.yabai

# Restart skhd hotkey daemon
restart-skhd:
    launchctl kickstart -k gui/$(id -u)/org.nixos.skhd

# Restart sketchybar
restart-sketchybar:
    launchctl kickstart -k gui/$(id -u)/org.nixos.sketchybar

# Restart all window management services (WM-aware)
restart-wm:
    #!/usr/bin/env bash
    WM_BACKEND=$(grep -o 'myOptions.windowManager.backend = "[^"]*"' hosts/darwin/default.nix | cut -d'"' -f2)
    if [ "$WM_BACKEND" = "yabai" ]; then
        echo "Restarting yabai..."
        launchctl kickstart -k gui/$(id -u)/org.nixos.yabai
        echo "Restarting skhd..."
        launchctl kickstart -k gui/$(id -u)/org.nixos.skhd
    elif [ "$WM_BACKEND" = "aerospace" ]; then
        echo "Restarting AeroSpace..."
        pkill -x AeroSpace; sleep 1; open -a AeroSpace
    fi
    echo "Restarting sketchybar..."
    launchctl kickstart -k gui/$(id -u)/org.nixos.sketchybar
    echo "All services restarted!"
