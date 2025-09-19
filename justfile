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
        nix build .#darwinConfigurations.aarch64-darwin.system; \
    elif [ -f /proc/version ] && grep -qi microsoft /proc/version; then \
        nix build .#nixosConfigurations.wsl.config.system.build.toplevel; \
    else \
        nix build .#nixosConfigurations.vboxnixos.config.system.build.toplevel; \
    fi

# Switch to new configuration (auto-detects platform)
switch *ARGS:
    @if [ "{{os()}}" = "macos" ]; then \
        printf "\033[1;33mStarting darwin switch...\033[0m\n"; \
        export NIXPKGS_ALLOW_UNFREE=1; \
        nh darwin switch -H aarch64-darwin . {{ARGS}}; \
        printf "\033[1;33mLoading yabai scripting addition...\033[0m\n"; \
        sudo yabai --load-sa; \
        printf "\033[1;32mYabai scripting addition loaded!\033[0m\n"; \
        printf "\033[1;32mSwitch to new generation complete!\033[0m\n"; \
    elif [ -f /proc/version ] && grep -qi microsoft /proc/version; then \
        printf "\033[1;33mStarting NixOS WSL switch...\033[0m\n"; \
        nh os switch --hostname wsl . {{ARGS}}; \
        printf "\033[1;32mNixOS WSL switch complete!\033[0m\n"; \
    else \
        printf "\033[1;33mStarting NixOS switch...\033[0m\n"; \
        nh os switch --hostname vboxnixos . {{ARGS}}; \
        printf "\033[1;32mNixOS switch complete!\033[0m\n"; \
    fi

# Build specific configuration
build-darwin:
    nix build .#darwinConfigurations.aarch64-darwin.system

build-wsl:
    nix build .#nixosConfigurations.wsl.config.system.build.toplevel

build-vbox:
    nix build .#nixosConfigurations.vboxnixos.config.system.build.toplevel

# Enter development shell with tools
dev:
    nix develop

# Clean up build artifacts
clean:
    rm -f result*

# Show flake info
info:
    nix flake info

# Update flake inputs
update:
    nix flake update

# Format check (don't format, just check)
fmt-check:
    find . -name "*.nix" -type f -exec nixfmt --check {} \;

# Lint nix files with statix
lint:
    statix check .

# Auto-fix linting issues with statix
lint-fix:
    statix fix .
