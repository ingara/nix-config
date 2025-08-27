# Nix configuration development tasks

default:
    @just --list

# Format all nix files with nixfmt-rfc-style
fmt:
    find . -name "*.nix" -type f -exec nixfmt {} \;

# Check nix configuration for errors
check:
    nix flake check

# Build the darwin configuration
build:
    nix build .#darwinConfigurations.aarch64-darwin.system

# Quick darwin-rebuild switch (equivalent to nix run .#nh-switch)
switch:
    #!/usr/bin/env bash
    set -euo pipefail
    GREEN='\033[1;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
    
    echo -e "${YELLOW}Starting darwin switch with nh...${NC}"
    export NIXPKGS_ALLOW_UNFREE=1
    nh darwin switch -H aarch64-darwin . "$@"
    
    echo -e "${YELLOW}Loading yabai scripting addition...${NC}"
    sudo yabai --load-sa
    echo -e "${GREEN}Yabai scripting addition loaded!${NC}"
    
    echo -e "${GREEN}Switch to new generation complete with nh!${NC}"

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
