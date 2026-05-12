{ pkgs, lib, ... }:
{
  projectRootFile = "flake.nix";

  programs = {
    # Nix
    nixfmt.enable = true;
    statix.enable = true;
    deadnix.enable = true;

    # Lua (nvim config)
    stylua.enable = true;

    # Shell
    shfmt.enable = true;
    shellcheck = {
      enable = true;
      severity = "warning"; # skip info-level (SC1091, SC2029)
    };

    # TOML
    taplo.enable = true;

    # YAML
    yamlfmt.enable = true;
    yamllint = {
      enable = true;
      settings = {
        extends = "default";
        rules = {
          line-length.max = 200;
          document-start = "disable";
        };
      };
    };

    # JSON + Markdown
    prettier = {
      enable = true;
      includes = [
        "*.json"
        "*.md"
      ];
    };
  };

  # Custom formatters not bundled with treefmt-nix.

  # Selene: lua linter. Config at public/selene.toml with LazyVim-friendly rules.
  settings.formatter.selene = {
    command = lib.getExe pkgs.selene;
    options = [
      "--config"
      "public/selene.toml"
    ];
    includes = [ "*.lua" ];
  };

  # treefmt's default walker is `git ls-files`, so .gitignore'd paths are
  # already skipped (result*, .notes/, .direnv, etc.). Only list TRACKED
  # files we want to skip:
  settings.global.excludes = [
    "flake.lock"
    "public/flake.lock"
    "secrets/*.yaml" # sops-encrypted (ciphertext lines exceed yamllint max)
    "dotfiles/claude/settings.json" # runtime-mutable by Claude Code
    "public/dotfiles/nvim/scratch_config.json"
    "public/dotfiles/nvim/.neoconf.json"
    "public/dotfiles/nvim/LICENSE"
  ];
}
