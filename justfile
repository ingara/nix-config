# Nix configuration development tasks

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
    #!/usr/bin/env bash
    if [[ "$OSTYPE" == "darwin"* ]]; then
        nix build .#darwinConfigurations.aarch64-darwin.system
    elif [[ -f /proc/version ]] && grep -qi microsoft /proc/version; then
        nix build .#nixosConfigurations.wsl.config.system.build.toplevel
    else
        nix build .#nixosConfigurations.vboxnixos.config.system.build.toplevel
    fi

# Switch to new configuration (auto-detects platform)
switch:
    @bash -euo pipefail -c ' \
    GREEN="\033[1;32m"; \
    YELLOW="\033[1;33m"; \
    NC="\033[0m"; \
    if [[ "$$OSTYPE" == "darwin"* ]]; then \
        echo -e "$${YELLOW}Starting darwin switch...$${NC}"; \
        export NIXPKGS_ALLOW_UNFREE=1; \
        nh darwin switch -H aarch64-darwin . "$$@"; \
        echo -e "$${YELLOW}Loading yabai scripting addition...$${NC}"; \
        sudo yabai --load-sa; \
        echo -e "$${GREEN}Yabai scripting addition loaded!$${NC}"; \
        echo -e "$${GREEN}Switch to new generation complete!$${NC}"; \
    elif [[ -f /proc/version ]] && grep -qi microsoft /proc/version; then \
        echo -e "$${YELLOW}Starting NixOS WSL switch...$${NC}"; \
        nh os switch --hostname wsl . "$$@"; \
        echo -e "$${GREEN}NixOS WSL switch complete!$${NC}"; \
    else \
        echo -e "$${YELLOW}Starting NixOS switch...$${NC}"; \
        nh os switch --hostname vboxnixos . "$$@"; \
        echo -e "$${GREEN}NixOS switch complete!$${NC}"; \
    fi' -- "$@"

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
