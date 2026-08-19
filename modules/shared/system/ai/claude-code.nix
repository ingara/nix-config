# Claude Code managed-settings.json (Anthropic's enterprise / IT policy file).
#
# Highest-precedence settings scope: cannot be overridden by user, project,
# or local settings, and Claude Code never writes back to it. Used as the
# Nix-baked layer for fields enforced declaratively across all hosts:
# policy (permissions allow rules, env, includeCoAuthoredBy) plus stable
# preference scalars the user doesn't toggle per-session (effortLevel,
# alwaysThinkingEnabled, theme, notification prefs).
#
# `model` is deliberately LEFT in user scope: pinning it here would lock
# the in-session `/model` switch (managed scope outranks even CLI args), so
# model stays a runtime-mutable field in ~/.config/claude/settings.json.
# This module does not manage that user-scope file.
#
# Private / host-specific additions (enabledPlugins, extraKnownMarketplaces,
# statusLine, autoMode trust hints, claudeMd personal instructions) are
# injected via `myOptions.claudeCode.extraManagedSettings` and merged in
# below — keeping identity-flavoured config out of this public module.
#
# Paths and merge semantics:
#   - macOS:        /Library/Application Support/ClaudeCode/managed-settings.json
#   - Linux/NixOS:  /etc/claude-code/managed-settings.json
#   - Arrays (e.g. permissions.allow) concatenate-and-dedupe across scopes;
#     scalars in managed scope cannot be overridden by user/project.
#
# Refs: https://docs.claude.com/en/docs/claude-code/settings
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  # Generic policy + stable preference scalars. Host-specific / private
  # additions come from myOptions.claudeCode.extraManagedSettings and are
  # recursiveUpdate-merged over this base (private keys win on conflict).
  baseManagedSettings = {
    # Stable preferences the user manages declaratively rather than via the
    # in-app UI. Locked here on purpose — change them in Nix + redeploy.
    alwaysThinkingEnabled = true;
    effortLevel = "high";
    theme = "custom:stylix";
    preferredNotifChannel = "terminal_bell";
    agentPushNotifEnabled = true;
    # Auto-connect Remote Control for every interactive session (tri-state:
    # unset would follow the organization default). Requires v2.1.119+.
    remoteControlAtStartup = true;

    env = {
      # NOTE: DISABLE_TELEMETRY and CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC are
      # deliberately NOT set here. Remote Control's eligibility check fails if
      # either is present, since the feature rides the telemetry/registration
      # channel. Keeping error reporting off is fine (it doesn't gate RC).
      CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
      DISABLE_ERROR_REPORTING = "1";
      # Disable auto memory (the per-repo store Claude writes itself) across
      # all hosts. Durable conventions belong in committed AGENTS.md/CLAUDE.md,
      # not an opaque, non-portable, machine-local memory dir.
      CLAUDE_CODE_DISABLE_AUTO_MEMORY = "1";
    };

    # Empty `commit`/`pr` suppress the Co-Authored-By footer — both are
    # required, since defining either one alone falls the other back to its
    # default attribution text. sessionUrl drops the Claude-Session trailer
    # and PR-body link, which otherwise fires on every session here via
    # remoteControlAtStartup.
    attribution = {
      commit = "";
      pr = "";
      sessionUrl = false;
    };

    # Managed (or user) scope is mandatory here: Claude Code ignores a
    # defaultMode of "auto" from project/local settings, since those are
    # repo-controllable and a clone could otherwise disarm the permission prompt.
    permissions.defaultMode = "auto";

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

    # Mechanical secret backstop, managed-locked so no user/project/local scope
    # can relax it, evaluated before allow. A Read deny also covers the Edit and
    # Write tools on the same path, and matches whether the symlink or its target
    # lands in a denied path. These gate the Read/Edit/Write tools, not a shell
    # `cat` of the same file — the airtight read boundary is the OS sandbox
    # (sandbox.denyRead), not yet enabled here.
    permissions.deny = [
      # Home-dir credential stores. ~/.aws/config stays readable (non-secret
      # profile definitions); only the creds file and the SSO bearer cache go.
      "Read(~/.ssh/**)"
      "Read(~/.aws/credentials)"
      "Read(~/.aws/sso/**)"
      "Read(~/.config/gcloud/**)"
      "Read(~/.config/sops/**)"
      "Read(~/Library/Application Support/sops/**)"
      # Secret-bearing file classes, at any depth.
      "Read(**/.env)"
      "Read(**/*.pem)"
      "Read(**/*.age)"
      # sops decryption to stdout. Best-effort only — shell argument matching is
      # not a trust boundary (the file-read denies and the sandbox are the real
      # control) — but it blocks the obvious forms per the never-decrypt rule.
      "Bash(sops -d *)"
      "Bash(sops --decrypt *)"
      "Bash(sops decrypt *)"
    ];
  };

  # Private / host-specific overlay wins on conflicting leaf keys.
  managedSettings = lib.recursiveUpdate baseManagedSettings config.myOptions.claudeCode.extraManagedSettings;

  managedSettingsJson = pkgs.writeText "claude-managed-settings.json" (
    builtins.toJSON managedSettings
  );

  inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;
in
lib.mkMerge [
  # CLAUDE_CONFIG_DIR points into the XDG dir (Claude Code ignores
  # XDG_CONFIG_HOME) for parity with every other tool.
  #
  # ~/.claude still appears and is expected: the herdr usagebar collector
  # hardcodes it for its cache with no env or config override, so it holds
  # regenerable cache only. Don't symlink it onto the real config
  # dir — `rm -rf ~/.claude/` and `~/.claude/*` both follow through, and the
  # sibling ~/.claude.json is outside any such link anyway.
  {
    environment.systemPackages = [
      inputs.claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
    ];
    environment.variables.CLAUDE_CONFIG_DIR = "$HOME/.config/claude";
    home-manager.sharedModules = [
      ({ config, ... }: {
        programs.herdr.integrations.claude = {
          directories = [ "${config.xdg.configHome}/claude" ];
          environment.CLAUDE_CONFIG_DIR = "${config.xdg.configHome}/claude";
        };
      })
    ];
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
