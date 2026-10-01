{
  config,
  lib,
  ...
}:
let
  # Selectable window managers (darwin: yabai..nehir; linux: hyprland/niri),
  # partitioned by class in _wm-names.nix — the single source for the
  # windowManager `enabled`/`default` enums below and the per-class validity
  # assertion in home/default.nix, so adding a WM is one edit there.
  wmClasses = import ./_wm-names.nix;
  wmNames = wmClasses.darwin ++ wmClasses.linux;
  gitAuthorType = lib.types.submodule {
    options = {
      name = lib.mkOption { type = lib.types.str; };
      email = lib.mkOption { type = lib.types.str; };
    };
  };
  personalGitAuthor = {
    name = config.myOptions.user.fullName;
    email = config.myOptions.user.email;
  };
  agentGitAuthor = personalGitAuthor // {
    name = "${config.myOptions.user.fullName} (agent)";
  };
  developerEnvironmentPackageType = lib.types.submodule {
    options = {
      package = lib.mkOption {
        type = lib.types.package;
        description = "Package that realizes this developer-environment capability.";
      };
      commands = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Commands provided by the capability for runtime parity probes.";
      };
    };
  };
  developerEnvironmentSurfaceType = lib.types.submodule {
    freeformType = lib.types.lazyAttrsOf lib.types.anything;
  };
  remoteMcpServerType = lib.types.submodule {
    options = {
      url = lib.mkOption {
        type = lib.types.addCheck lib.types.str (
          url: builtins.match "https?://[^/[:space:]][^[:space:]]*" url != null
        );
        description = "Absolute HTTP(S) endpoint for a hosted MCP server.";
      };
      enabled = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether this server is emitted into client configuration.";
      };
      bearerTokenFiles = lib.mkOption {
        type = lib.types.submodule {
          options =
            lib.genAttrs
              [
                "personal"
                "agent"
              ]
              (
                _:
                lib.mkOption {
                  type = lib.types.nullOr (lib.types.addCheck lib.types.str (path: lib.hasPrefix "/" path));
                  default = null;
                  description = "Absolute runtime path to this identity's bearer token file.";
                }
              );
        };
        default = { };
        description = ''
          Protected runtime bearer-token files by execution identity. When both
          entries are null, projection remains credential-free. Paths may be rendered
          into generated configuration; token contents must not enter the Nix
          store.
        '';
      };
    };
  };
in
{
  options.myOptions = {
    executionIdentity = lib.mkOption {
      type = lib.types.enum [
        "personal"
        "agent"
      ];
      default = "personal";
      description = ''
        Execution identity whose authority policy is composed with the shared
        developer environment.
      '';
    };
    developerEnvironmentParity = {
      packages = lib.mkOption {
        type = lib.types.attrsOf developerEnvironmentPackageType;
        default = { };
        internal = true;
        description = ''
          Owner-maintained registry of credential-free developer packages and
          the commands each capability exposes.
        '';
      };
      aliases = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        internal = true;
        description = "Portable Fish aliases included in developer-environment parity checks.";
      };
      surfaces = lib.mkOption {
        type = lib.types.attrsOf developerEnvironmentSurfaceType;
        default = { };
        internal = true;
        description = ''
          Credential-free, JSON-safe configuration surfaces registered beside
          their owning modules for developer-environment parity checks.
        '';
      };
      projection = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        readOnly = true;
        internal = true;
        description = "Normalized developer-environment projection produced by the owning composition.";
      };
    };
    user = {
      username = lib.mkOption {
        type = lib.types.str;
        default = "user";
      };
      fullName = lib.mkOption {
        type = lib.types.str;
        default = "Nix User";
      };
      email = lib.mkOption {
        type = lib.types.str;
        default = "user@example.com";
      };
      signingKey = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
    };
    gitAuthors = {
      personal = lib.mkOption {
        type = gitAuthorType;
        default = personalGitAuthor;
        description = "Git author used by the personal execution identity.";
      };
      agent = lib.mkOption {
        type = gitAuthorType;
        default = agentGitAuthor;
        description = "Git author used by the agent execution identity.";
      };
    };
    dotfiles = {
      repoRoot = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Root path of the nix-config repo, used for dotfile symlinks";
      };
    };
    opencode = {
      hostClass = lib.mkOption {
        type = lib.types.enum [
          "workstation"
          "server"
        ];
        default = "workstation";
        description = ''
          Selects which opencode permission profile is symlinked to
          ~/.config/opencode/opencode.json. "server" adds outbound
          network/exec denies (ssh/scp/rsync/nc) and shutdown/reboot denies
          on top of the workstation profile.
        '';
      };
    };
    mcp.servers = lib.mkOption {
      type = lib.types.attrsOf remoteMcpServerType;
      default = { };
      description = ''
        Hosted MCP servers projected into supported clients. Bearer token
        contents remain mutable protected state; only their runtime paths are
        represented here.
      '';
    };
    hasGui = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    windowManager = {
      # Set+default model. `enabled` = which WMs are installed and configured
      # (casks installed, dotfiles rendered, services declared); `default` =
      # the active/login WM (drives the /etc/nix-config/wm-backend marker and
      # single-active surfaces like yabai's scripting addition). Both scopes
      # (system + HM) on both platforms read this; per-platform modules gate on
      # `elem` membership. Darwin WMs: yabai/aerospace/omniwm/paneru/nehir;
      # Linux WMs: hyprland/niri. The per-class validity rule (no darwin WM in
      # `enabled` on Linux, and `default ∈ enabled`) is enforced by assertions
      # in shared/home/default.nix, not by type narrowing.
      #
      # Multi-WM *run-one*: for the open-a-lifecycle WMs (nehir/omniwm) a 2+
      # `enabled` list installs all of them, and a single `wm-autostart` agent
      # runs `wm-switch <default>` at login to launch exactly one (see
      # modules/darwin/window-manager.nix). yabai self-starts via services.yabai.
      enabled = lib.mkOption {
        type = lib.types.listOf (lib.types.enum wmNames);
        default = [ ];
        description = ''
          Window managers to install and configure. Each WM module self-gates
          on membership here; multiple may be installed at once, with `default`
          selecting the active one.
        '';
      };
      default = lib.mkOption {
        type = lib.types.enum (wmNames ++ [ "none" ]);
        default = "none";
        description = ''
          The active/login window manager (must be "none" or a member of
          `enabled`). Drives the /etc/nix-config/wm-backend marker.
        '';
      };
      omniwm.routing.arrangements = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              id = lib.mkOption { type = lib.types.str; };
              monitors = lib.mkOption {
                type = lib.types.listOf (
                  lib.types.submodule {
                    options = {
                      monitorName = lib.mkOption { type = lib.types.str; };
                      monitorDisplayUUID = lib.mkOption { type = lib.types.str; };
                      gridColumn = lib.mkOption { type = lib.types.int; };
                      gridRow = lib.mkOption { type = lib.types.int; };
                    };
                  }
                );
              };
            };
          }
        );
        default = [ ];
        description = "UUID-keyed OmniWM routing grids; an empty list follows the macOS arrangement.";
      };
    };
    mutableDotfiles = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    sshSignProgram = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    gitCredentialHelper = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    # Consumed by system/ai/agent-git.nix. Declared here because the whole
    # myOptions tree is forwarded into home-manager, so a system-only
    # declaration breaks HM's copy.
    agentGit = {
      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = ''
          GitHub credential routing package. When unset, the in-tree package is
          used.
        '';
      };

      ghPackage = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        internal = true;
        description = "Generated gh package with agent credential routing.";
      };

      ownerTokens = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        example = lib.literalExpression ''{ someowner = "/run/secrets/github-token"; }'';
        description = ''
          Map of GitHub owner to a file holding a token with write access to
          that owner's repos. One token per owner is a GitHub constraint: a
          fine-grained PAT is scoped to a single resource owner. Routing
          prevents accidental credential crossover and operator fallback;
          repository and permission limits come from each token's GitHub scope.
        '';
      };

      projectsToken = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "/run/secrets/github-projects-token";
        description = ''
          File holding a token limited to GitHub Projects and the metadata read
          scope required by the gh CLI. The router selects it automatically for
          `gh project` commands and exposes it as the named Projects credential.
        '';
      };

      signingKeyFile = lib.mkOption {
        type = lib.types.str;
        default = "";
        internal = true;
        description = "Private SSH signing key used by the rendered agent gitconfig.";
      };

      allowedSignersFile = lib.mkOption {
        type = lib.types.str;
        default = "";
        internal = true;
        description = "SSH allowed-signers file used by the rendered agent gitconfig.";
      };

      gitconfigPath = lib.mkOption {
        type = lib.types.str;
        default = "";
        internal = true;
        description = "Rendered agent gitconfig; consumed by the agent harness modules.";
      };
    };
    claudeCode = {
      extraManagedSettings = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = ''
          Per-host / private additions merged (via lib.recursiveUpdate)
          into the Nix-baked Claude Code managed-settings.json. The public
          module sets generic policy + stable preference scalars; private
          or host-specific keys (enabledPlugins, extraKnownMarketplaces,
          statusLine, autoMode trust hints, claudeMd) are injected here so
          they stay out of the public module. Highest-precedence scope:
          keys set here cannot be overridden by Claude's in-app UI.
        '';
      };
    };
    codex = {
      linkedWorktreeGitWrite = lib.mkEnableOption ''
        writable Git metadata for linked worktrees. The Codex launcher adds
        only the current worktree's common Git directory as an extra workspace
        root; the main checkout remains outside the sandbox's write roots
      '';

      extraSystemConfig = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = ''
          Per-host / private additions merged (via lib.recursiveUpdate) into
          the Nix-baked /etc/codex/config.toml. The public module sets generic
          policy; permission profiles are injected here, since a profile
          encodes which paths one workflow needs to write.

          A profile set here MUST define `extends`. Codex accepts a profile
          table without one, then aborts — SIGABRT, exit 134, nothing on
          stdout or stderr — the moment that profile is selected.
        '';
      };
    };
    theme = {
      scheme = lib.mkOption {
        type = lib.types.enum [
          "rose-pine"
          "rose-pine-moon"
          "rose-pine-dawn"
          "tokyo-night-dark"
          "tokyo-night-storm"
          "tokyo-night-moon"
          "tokyo-night-light"
          "kanagawa"
          "kanagawa-dragon"
        ];
        default = "rose-pine-moon";
        description = ''
          Active base16 color scheme. Drives Stylix across every themed
          surface (terminals, editors, status bars, GTK/Qt, KDE Plasma,
          cursors). Scheme names map 1:1 to YAML files in
          inputs.tinted-schemes/base16/<name>.yaml.
        '';
      };
      polarity = lib.mkOption {
        type = lib.types.enum [
          "light"
          "dark"
          "either"
        ];
        default = "dark";
        description = ''
          Forces light or dark variants where the target app supports
          both, or "either" to let Stylix pick.
        '';
      };
    };
  };
}
