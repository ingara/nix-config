# Claude Code managed-settings.json (Anthropic's enterprise / IT policy file).
#
# Highest-precedence settings scope: cannot be overridden by user, project,
# or local settings, and Claude Code never writes back to it. Used as the
# Nix-baked layer for fields enforced declaratively across all hosts:
# permissions allow rules, env, and the includeCoAuthoredBy preference.
#
# Fields that Claude mutates at runtime (model, effortLevel,
# alwaysThinkingEnabled, voice) and per-host fields (statusLine command
# path) stay in the user-scope ~/.config/claude/settings.json — this
# module deliberately does not manage that file.
#
# Paths and merge semantics:
#   - macOS:        /Library/Application Support/ClaudeCode/managed-settings.json
#   - Linux/NixOS:  /etc/claude-code/managed-settings.json
#   - Arrays (e.g. permissions.allow) concatenate-and-dedupe across scopes;
#     scalars in managed scope cannot be overridden by user/project.
#
# Refs: https://docs.claude.com/en/docs/claude-code/settings
{
  lib,
  pkgs,
  ...
}:

let
  managedSettings = {
    env = {
      DISABLE_TELEMETRY = "1";
      CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
      CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
      DISABLE_ERROR_REPORTING = "1";
    };

    # Suppress the Co-Authored-By footer in commits and PRs. Marked
    # deprecated upstream in favour of `attribution`, but still respected.
    includeCoAuthoredBy = false;

    permissions.allow = [
      # JS build/test loops
      "Bash(pnpm lint)"
      "Bash(pnpm lint:fix)"
      "Bash(pnpm check)"
      "Bash(pnpm test)"
      "Bash(pnpm type-check)"

      # Web search and read-only HTTP fetches via xh. Mutating verbs
      # (POST/PUT/DELETE) cannot be reordered into a GET allow rule the
      # way `curl -X POST` can.
      "WebSearch"
      "Bash(xh GET:*)"
      "Bash(xh HEAD:*)"
      "Bash(xh OPTIONS:*)"

      # JSON munging
      "Bash(jq:*)"

      # gh — read-only subcommands. Mutating verbs (gh api, gh auth,
      # gh issue create, gh pr merge, gh repo delete, etc.) deliberately
      # fall through to ask-by-default. Mirrors the opencode allowlist
      # in modules/shared/home/ai/opencode.nix.
      "Bash(gh pr checks:*)"
      "Bash(gh pr view:*)"
      "Bash(gh pr list:*)"
      "Bash(gh pr diff:*)"
      "Bash(gh issue view:*)"
      "Bash(gh issue list:*)"
      "Bash(gh repo view:*)"
    ];
  };

  managedSettingsJson = pkgs.writeText "claude-managed-settings.json" (
    builtins.toJSON managedSettings
  );

  inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;
in
lib.mkMerge [
  # CLAUDE_CONFIG_DIR env var — Claude Code does not respect XDG_CONFIG_HOME,
  # so we point it explicitly into the XDG directory for consistency with
  # every other tool.
  {
    environment.variables.CLAUDE_CONFIG_DIR = "$HOME/.config/claude";
  }

  # Cachix substituter for the claude-code-nix flake input. Without this,
  # `claude-code` is missing from cache.nixos.org (it's a custom flake, not
  # a nixpkgs package) and every deploy that bumps its version source-builds
  # the ~180MB native binary downloader. The Cachix is hourly-updated by the
  # claude-code-nix CI; see
  # https://github.com/sadjow/claude-code-nix#optional-enable-binary-cache-for-faster-installation
  #
  # Trade-off: trusts the substituter's signing key. Trust delta is small
  # since we already trust the flake input itself (which fetches binaries
  # from Anthropic with fixed hashes).
  {
    nix.settings = {
      extra-substituters = [ "https://claude-code.cachix.org" ];
      extra-trusted-public-keys = [
        "claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk="
      ];
    };
  }

  (lib.mkIf isLinux {
    environment.etc."claude-code/managed-settings.json".source = managedSettingsJson;
  })

  (lib.mkIf isDarwin {
    # macOS path is outside /etc, so environment.etc can't reach it.
    # Drop a symlink into the system path via postActivation.
    system.activationScripts.postActivation.text = lib.mkAfter ''
      echo "setting up Claude Code managed settings..."
      mkdir -p "/Library/Application Support/ClaudeCode"
      ln -sf "${managedSettingsJson}" \
        "/Library/Application Support/ClaudeCode/managed-settings.json"
    '';
  })
]
