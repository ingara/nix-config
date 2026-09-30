# OpenAI Codex CLI: binary and system config together, so importing this module
# installs a configured Codex — no separate per-host wiring.
#
# CODEX_HOME → XDG. Codex keeps its whole state dir (config.toml, credentials,
# history, the session db) under ~/.codex and ignores XDG (openai/codex#1980);
# CODEX_HOME relocates the root to ~/.config/codex. The user config.toml stays
# Codex-owned — it rewrites it at runtime (model, per-project trust_level, TUI
# theme), so a read-only Nix copy would fight those writes.
#
# requirements.toml is the opposite kind of file: a system policy layer Codex
# only ever reads, at /etc/codex/requirements.toml (the loader path is
# cfg(unix), so darwin and nixos share it). The ceiling below forbids both
# `danger-full-access`, which drops the Landlock+seccomp jail, and
# `approval_policy = never`. Codex 0.149 rejects `untrusted` as an explicit
# user setting but still derives it internally for untrusted projects, so the
# requirements layer must allow that stricter mode alongside `on-request`.
# The ceiling holds even against a prompt-injected or fat-fingered
# --dangerously-bypass-approvals-and-sandbox.
#
# Cachix: codex-cli-nix isn't on cache.nixos.org, so without its substituter
# every version bump re-derives upstream's own derivation. It doesn't cover the
# symlinkJoin below — symlinkJoin sets allowSubstitutes = false, so that one is
# always built locally, cheaply.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  mcpAuth = import ../../_mcp-auth.nix { inherit lib; };
  upstreamCodex = inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.codex;
  enabledMcpServers = lib.filterAttrs (_: server: server.enabled) config.myOptions.mcp.servers;
  mkBearerHeaderHelper =
    name: server:
    pkgs.writeShellApplication {
      name = "codex-mcp-bearer-headers-${builtins.substring 0 16 (builtins.hashString "sha256" name)}";
      runtimeInputs = [ pkgs.jq ];
      text = ''
        token_file=
        token_paths=(${lib.escapeShellArgs (mcpAuth.bearerTokenPaths server)})
        for candidate in "''${token_paths[@]}"; do
          if [[ -r "$candidate" ]]; then
            if [[ -n "$token_file" ]]; then
              printf 'Codex MCP bearer token selection is ambiguous\n' >&2
              exit 1
            fi
            token_file="$candidate"
          fi
        done

        if [[ -z "$token_file" ]]; then
          printf 'Codex MCP bearer token is unavailable\n' >&2
          exit 1
        fi

        token="$(< "$token_file")"
        if [[ -z "$token" || "$token" == *$'\n'* || "$token" == *$'\r'* ]]; then
          printf 'Codex MCP bearer token is empty or malformed\n' >&2
          exit 1
        fi

        printf '%s' "$token" | jq -Rs '{ Authorization: ("Bearer " + .) }'
      '';
    };

  # Herdr names a pane's agent from the foreground process's argv[0], which
  # codex-cli-nix's wrapper chain replaces with its own store path — so Codex
  # panes register as no agent at all. HERDR_AGENT is Herdr's documented
  # override for wrappers that mask the real process:
  # https://herdr.dev/docs/agents/#vms-and-sandbox-wrappers
  #
  # It must ride the package, not the session environment: Codex and everything
  # it spawns inherit the hint, and exported globally it would label every pane
  # as Codex. set-default so an explicit HERDR_AGENT still wins, which is how
  # Herdr documents relabelling an invocation.
  #
  # Verify: run `codex` in a pane, then `herdr agent list` reports agent "codex".
  codex = pkgs.symlinkJoin {
    name = "codex-herdr-${upstreamCodex.version}";
    paths = [ upstreamCodex ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    # symlinkJoin builds a bare runCommand; without this the package loses
    # meta.mainProgram and lib.getExe fails on it.
    inherit (upstreamCodex) meta;
    postBuild = ''
      wrapProgram "$out/bin/codex" ${
        lib.escapeShellArgs (
          [
            "--set-default"
            "HERDR_AGENT"
            "codex"
          ]
          ++ lib.optionals config.myOptions.codex.linkedWorktreeGitWrite [
            "--run"
            ''
              codex_cwd=$PWD
              codex_expect_cwd=
              for codex_arg in "$@"; do
                if [ -n "$codex_expect_cwd" ]; then
                  codex_cwd=$codex_arg
                  codex_expect_cwd=
                  continue
                fi
                case "$codex_arg" in
                  --)
                    break
                    ;;
                  -C|--cd)
                    codex_expect_cwd=1
                    ;;
                  --cd=*)
                    codex_cwd=''${codex_arg#--cd=}
                    ;;
                esac
              done

              if codex_worktree_root="$(${lib.getExe pkgs.git} -C "$codex_cwd" rev-parse --path-format=absolute --show-toplevel 2>/dev/null)" \
                && [ -f "$codex_worktree_root/.git" ] \
                && codex_common_git_dir="$(${lib.getExe pkgs.git} -C "$codex_cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"; then
                set -- --add-dir "$codex_common_git_dir" "$@"
              fi
            ''
          ]
        )
      }
    '';
  };

  baseSystemConfig = {
    mcp_servers = lib.mapAttrs (
      name: server:
      {
        inherit (server) url;
      }
      // lib.optionalAttrs (mcpAuth.hasBearerToken server) {
        http_headers_helper = lib.getExe (mkBearerHeaderHelper name server);
      }
    ) enabledMcpServers;

    # Strip vars whose name contains KEY/SECRET/TOKEN from the environment Codex
    # hands to the shell commands it spawns. Codex's own process is unaffected —
    # it keeps whatever the launching shell exported, so a provider that reads
    # its key from the env still authenticates; only the *subprocess* env is
    # scrubbed. Default is off: ignore_default_excludes defaults true, i.e. the
    # scrub disabled. Escape hatch for a command that genuinely needs one:
    # shell_environment_policy.set.<NAME> re-adds it after the exclusion pass.
    shell_environment_policy = {
      ignore_default_excludes = false;
    };

    # Repository workflows require durable, user-visible progress tracking.
    tools.update_plan.enabled = true;

    tui = {
      status_line = [
        "project-name"
        "git-branch"
        "branch-changes"
        "model-with-reasoning"
        "context-used"
        "total-input-tokens"
        "total-output-tokens"
      ];
      status_line_use_colors = true;
    };
  };

  # Private / host-specific overlay wins on conflicting leaf keys.
  systemConfigToml = (pkgs.formats.toml { }).generate "codex-system-config.toml" (
    lib.recursiveUpdate baseSystemConfig config.myOptions.codex.extraSystemConfig
  );

  requirementsToml = (pkgs.formats.toml { }).generate "codex-requirements.toml" {
    allowed_sandbox_modes = [
      "read-only"
      "workspace-write"
    ];
    allowed_approval_policies = [
      "untrusted"
      "on-request"
    ];

    # OS-level (Seatbelt/Landlock) read denial, re-applied across profile swaps
    # so a session can't shed it. `~` expands to the invoking user's home at
    # parse time. A path with no glob metacharacter denies it and its whole
    # subtree; globs MUST be anchored with `~/` or `/` (a bare `**/.env` silently
    # anchors to /etc/codex and protects nothing).
    #
    # Deliberately narrow: deny_read is enforced against every process in the
    # sandbox, including the CLIs Codex runs, so it lists only paths no
    # legitimate tool needs. NOT here, and why:
    #   ~/.aws, ~/.config/gcloud — the aws/gcloud CLIs read their own config and
    #     SSO/token cache from these; denying breaks agent cloud work. Scoping
    #     that belongs with the Identity Center agent profiles, not a blunt deny.
    #   ~/.ssh — keys live in the 1Password agent, not on disk here; denying only
    #     risks breaking git-over-SSH (config, known_hosts).
    #   **/.env, **/*.pem — would break dev servers loading .env and Python's
    #     certifi CA bundle (cacert.pem).
    # The sops age keys and GPG are the safe, high-value entries: nothing an
    # agent legitimately runs reads them, and denying the age key is an
    # OS-level hard stop on `sops -d` — stronger than a shell-command deny.
    permissions.filesystem.deny_read = [
      "~/.config/sops"
      "~/Library/Application Support/sops"
      "~/.gnupg"
    ];
  };
in
{
  environment.systemPackages = [ codex ];

  environment.variables.CODEX_HOME = "$HOME/.config/codex";

  home-manager.sharedModules = [
    ({ config, ... }: {
      programs.herdr.integrations.codex = {
        directories = [ "${config.xdg.configHome}/codex" ];
        environment.CODEX_HOME = "${config.xdg.configHome}/codex";
      };
    })
  ];

  environment.etc."codex/requirements.toml".source = requirementsToml;
  environment.etc."codex/config.toml".source = systemConfigToml;

  nix.settings = {
    extra-substituters = [ "https://codex-cli.cachix.org" ];
    extra-trusted-public-keys = [
      "codex-cli.cachix.org-1:1Br3H1hHoRYG22n//cGKJOk3cQXgYobUel6O8DgSing="
    ];
  };
}
