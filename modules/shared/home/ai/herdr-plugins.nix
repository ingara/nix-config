# Herdr plugins, packaged as store-linked plugin roots.
#
# Each package's output *is* the plugin root — manifest at the top level — which
# is the shape `programs.herdr.plugins` links. Herdr skips a plugin's `[[build]]`
# steps on `link`, so anything the plugin would fetch or compile at install time
# has to be baked in here instead.
#
# Interpreters must be absolute: herdr runs `command = [...]` as argv with no
# shell, against the environment its *server* was launched with, which is not
# this activation's PATH. A bare `node` or `bash` resolves only by luck.
#
# On bumping any version or pin below: the `--replace-fail` patches are the
# safety net and need no manual re-check — an anchor upstream has moved or
# renamed fails the build with the pattern that missed. Read the error and
# re-target it.
#
# What that net does NOT catch is an anchor that gains a *second* occurrence:
# --replace-fail only errors when a pattern matches nothing, and otherwise
# substitutes every match silently. That is harmless where replacing all of them
# is the intent (every `"bash"`/`"node"` in a manifest), and wrong where the
# patch targets one specific site — so those assert their own uniqueness before
# substituting rather than trusting it.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.herdr;

  # Untagged upstream — no releases to track, so this is a dated commit pin:
  # bump it deliberately, and don't expect a version string to follow along.
  resurrectPin = {
    rev = "461e866cc772e156e39b94d085701972e24761af";
    date = "2026-07-12";
    hash = "sha256-PADoHDKDtCsXc3acojaxugxXaZfvCECvSNSwnhvW7hk=";
  };

  # Pure stdlib Node (no dependencies, no lockfile), so the source tree is the
  # finished plugin — only the interpreter needs resolving.
  herdr-resurrect = pkgs.stdenvNoCC.mkDerivation {
    pname = "herdr-resurrect";
    version = "0-unstable-${resurrectPin.date}";

    src = pkgs.fetchFromGitHub {
      owner = "ntindle";
      repo = "herdr-resurrect";
      inherit (resurrectPin) rev hash;
    };

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r . "$out/"
      substituteInPlace "$out/herdr-plugin.toml" \
        --replace-fail '"node"' '"${lib.getExe pkgs.nodejs}"'
      runHook postInstall
    '';

    meta = {
      description = "Snapshot and restore herdr workspaces, tabs, panes and agents";
      homepage = "https://github.com/ntindle/herdr-resurrect";
      license = lib.licenses.mit;
      platforms = lib.platforms.unix;
    };
  };

  # The review pane runs `$HERDR_PLUGIN_ROOT/bin/herdr-reviewr` by absolute
  # path, so the binary has to sit inside the plugin root alongside the manifest
  # and the `herdr/` scripts — hence a plugin-root-shaped output rather than a
  # plain `bin/` package.
  herdr-reviewr = pkgs.rustPlatform.buildRustPackage (finalAttrs: {
    pname = "herdr-reviewr";
    version = "0.29.0";

    src = pkgs.fetchFromGitHub {
      owner = "persiyanov";
      repo = "herdr-reviewr";
      tag = "v${finalAttrs.version}";
      hash = "sha256-xr9V9rJjT3RMir/luIn09eo2bXuw5Fxn3lkHHZXAOTA=";
    };

    cargoHash = "sha256-XNxymWF/3W+UgbYqMw4/ZHxgSBnofnNHh+RCfBjhhWQ=";

    nativeBuildInputs = [ pkgs.pkg-config ];
    # The tests drive the real scripts: git:: shells out to git (without it
    # `worktree_of` can't tell "outside a repo" from "couldn't tell"), and the
    # pane-action suite runs pane.sh, which parses its config with jq. The
    # postInstall PATH patch below can't help here — checks run before install,
    # against the unpatched source.
    nativeCheckInputs = [
      pkgs.git
      pkgs.jq
    ];
    buildInputs = [
      pkgs.libgit2
      pkgs.openssl
      pkgs.zlib
    ];
    # git2 arrives transitively; build it against nixpkgs' libgit2 rather than
    # letting libgit2-sys vendor and compile its own copy.
    env.LIBGIT2_NO_VENDOR = 1;

    # Several pane-action tests resolve the worktree of their own cwd and refuse
    # outright when it isn't a repo. fetchFromGitHub strips .git, so stand one up
    # rather than skipping the tests and losing the coverage.
    # Keep maintenance synchronous so no detached child holds .git/maintenance.lock
    # during TempDir teardown. REMOVE WHEN upstream waits for maintenance completion.
    preCheck = ''
      export HOME="$TMPDIR"
      git config --global maintenance.autoDetach false
      git init -q -b main .
      git -c user.email=nix@localhost -c user.name=nix commit -q --allow-empty -m "build sandbox"
    '';

    postInstall = ''
      cp -r herdr "$out/herdr"
      cp herdr-plugin.toml "$out/herdr-plugin.toml"

      # Same argv-not-a-shell rule as above: the manifest's actions invoke bash
      # and the review pane invokes sh, so neither can rely on the server's
      # PATH. bashNonInteractive because `pkgs.bash` is the interactive build and
      # would drag readline and ncurses into a plugin that only runs scripts.
      substituteInPlace "$out/herdr-plugin.toml" \
        --replace-fail '"bash"' '"${lib.getExe pkgs.bashNonInteractive}"' \
        --replace-fail '"sh"' '"${lib.getExe pkgs.bashNonInteractive}"'

      # pane.sh hardcodes a PATH of /opt/homebrew, /usr/local, /usr and /bin
      # to find jq and git. None of those carry either on NixOS, so prepend the
      # store paths — otherwise every action dies at the first `jq`.
      substituteInPlace "$out/herdr/pane.sh" \
        --replace-fail 'export PATH="' 'export PATH="${
          lib.makeBinPath [
            pkgs.jq
            pkgs.git
          ]
        }:'
    '';

    meta = {
      description = "Review an agent's diff beside the chat and send line comments back";
      homepage = "https://github.com/persiyanov/herdr-reviewr";
      license = lib.licenses.mit;
      mainProgram = "herdr-reviewr";
      platforms = lib.platforms.unix;
    };
  });

  # A popup is not a workspace pane: herdr launches it through
  # `PaneLaunchEnv::without_pane_identity()`, which clears HERDR_PANE_ID and
  # sets no workspace identity at all, leaving only the HERDR_ACTIVE_* set that
  # `custom_command_env()` adds. reviewr's send reads HERDR_WORKSPACE_ID alone,
  # so unbridged the popup finds zero candidate agents and refuses with "no
  # agent here" — while the plugin-pane variant, which does get the identity,
  # sends fine.
  #
  # HERDR_ACTIVE_PANE_ID is deliberately *not* bridged to HERDR_PANE_ID: reviewr
  # reads that one to exclude its own pane from the candidates, and the active
  # pane is the agent the comments are for. It also gates the cosmetic pane-label
  # writes, which a popup has no pane to carry.
  reviewrPopup = pkgs.writeShellScript "herdr-reviewr-popup" ''
    if [ -n "$HERDR_ACTIVE_WORKSPACE_ID" ]; then
      export HERDR_WORKSPACE_ID="$HERDR_ACTIVE_WORKSPACE_ID"
    else
      # `without_pane_identity()` clears only HERDR_PANE_ID, and the server is
      # long-lived enough to have inherited a workspace id from whatever launched
      # it. Prefer none over a stale one: reviewr then refuses visibly instead of
      # sending the comments to an agent in some other workspace.
      unset HERDR_WORKSPACE_ID
    fi
    exec ${lib.getExe herdr-reviewr} "$@"
  '';

  # Ctrl+hjkl across nvim splits, herdr panes and — with the patch below — an
  # outer tmux. Upstream assumes herdr is the outermost multiplexer; running it
  # inside tmux adds a third layer it has no concept of.
  herdr-splits = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "herdr-splits";
    version = "0.5.1";

    src = pkgs.fetchFromGitHub {
      owner = "lmilojevicc";
      repo = "herdr-splits.nvim";
      tag = "v${finalAttrs.version}";
      hash = "sha256-wj4W7MqMIkiXxEgYJ2OXAEOcILFp6ThVH7Q82ce97dg=";
    };

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
        runHook preInstall
        mkdir -p "$out"
        cp -r . "$out/"

        substituteInPlace "$out/herdr-plugin.toml" \
          --replace-fail '"bash"' '"${lib.getExe pkgs.bashNonInteractive}"'

        # Default to `stop` rather than `wrap`. Upstream wraps to the opposite
        # side at a herdr edge; we want the edge to hand off outward to tmux
        # instead. The script only ever flips this default *to* stop when the
        # generated conf says so, so patching the default makes the behaviour
        # deterministic even before Neovim has written that conf.
        #
        # `exit 0` is a generic anchor, and --replace-fail only catches a pattern
        # that matched *nothing* — it replaces every match silently. So assert
        # uniqueness: a second one appearing upstream would otherwise get the
        # tmux handoff grafted onto an unrelated exit path, with no error.
        # `|| true` is load-bearing: grep -c exits 1 on zero matches, and phases
        # run under `set -e`, so without it the anchor-vanished case — the likelier
        # upstream drift — dies before reaching the message below.
        anchors=$(${pkgs.gnugrep}/bin/grep -c '^    exit 0$' "$out/scripts/herdr-nav.sh" || true)
        if [ "$anchors" -ne 1 ]; then
          echo "herdr-splits: expected exactly one '    exit 0' anchor, found $anchors." >&2
          echo "Upstream restructured herdr-nav.sh — re-read it and re-target the patch." >&2
          exit 1
        fi

        # Then the handoff itself: at an edge with `stop`, upstream simply exits.
        # Delegate to tmux there, which is what closes the nvim -> herdr -> tmux
        # chain. Target tmux's *active* pane rather than $TMUX_PANE — the herdr
        # server is long-lived and inherits that value from whichever client
        # started it, so it goes stale as soon as herdr is launched from a
        # different pane.
        substituteInPlace "$out/scripts/herdr-nav.sh" \
          --replace-fail 'nav_at_edge=wrap' 'nav_at_edge=stop' \
          --replace-fail '    exit 0' '    if [ -n "''${TMUX:-}" ]; then
        case "$dir" in
          left)  ${lib.getExe pkgs.tmux} select-pane -L ;;
          down)  ${lib.getExe pkgs.tmux} select-pane -D ;;
          up)    ${lib.getExe pkgs.tmux} select-pane -U ;;
          right) ${lib.getExe pkgs.tmux} select-pane -R ;;
        esac
      fi
      exit 0'
        runHook postInstall
    '';

    meta = {
      description = "Seamless navigation between Neovim splits, herdr panes and an outer tmux";
      homepage = "https://github.com/lmilojevicc/herdr-splits.nvim";
      license = lib.licenses.mit;
      platforms = lib.platforms.unix;
    };
  });
in
{
  options.programs.herdr.usagebar.enable = lib.mkEnableOption ''
    herdr-agent-usage, showing each agent pane's context use and its provider's
    plan window in the sidebar, plus rate-limit toasts. Reads local harness
    state only — no API keys
  '';

  options.programs.herdr.splits.enable = lib.mkEnableOption ''
    herdr-splits, giving Ctrl+hjkl one meaning across Neovim splits, herdr
    panes and an outer tmux. Pairs with the Neovim plugin, which must be
    gated on HERDR_ENV so it and smart-splits never both bind the keys
  '';

  options.programs.herdr.reviewr.enable = lib.mkEnableOption ''
    herdr-reviewr, a pane for reviewing an agent's diff: select lines,
    comment, and send every note back into the agent's input
  '';

  options.programs.herdr.resurrect.enable = lib.mkEnableOption ''
    herdr-resurrect, which snapshots the herd (workspaces, tabs, panes, cwd,
    running programs, agents) and restores it after a crash or reboot.

    Worth having wherever herdr is version-managed by Nix: a herdr upgrade
    forces a server restart that exits every pane, and herdr's only live
    handoff is bundled into its self-updater, which Nix-managed installs
    cannot use
  '';

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf cfg.resurrect.enable {
        programs.herdr.plugins.resurrect = {
          id = "ntindle.herdr-resurrect";
          package = herdr-resurrect;
        };
      })

      (lib.mkIf cfg.reviewr.enable {
        programs.herdr.plugins.reviewr = {
          id = "persiyanov.reviewr";
          package = herdr-reviewr;
        };

        # The plugin's worktree.created hook auto-opens a pane in every fresh
        # worktree (auto_open defaults to true); opt out so the binds below
        # stay the only entry points.
        xdg.configFile."herdr/plugins/config/persiyanov.reviewr/config.toml".source =
          (pkgs.formats.toml { }).generate "herdr-reviewr-config.toml"
            {
              auto_open = false;
            };

        # prefix+d for "diff". Prefix-gated rather than a bare chord so the
        # focused pane can't swallow it, and plain ASCII rather than
        # `ctrl+shift+*`, which rides the kitty keyboard protocol and may not
        # survive an SSH hop — herdr is driven over `--remote` here.
        #
        # Needs reviewr >= 0.27.0: any pane running the binary is a full reviewr
        # pane, fetching its plugin config from herdr itself. A popup inherits
        # the focused pane's cwd, so it reviews the repo under the cursor.
        #
        # `prefix+shift+d` is herdr's default `close_workspace`. A user binding
        # displaces a conflicting default at config load, so this takes the
        # chord and close_workspace ends up unbound — but only while
        # close_workspace itself stays at its default. Bind it explicitly and
        # both are user bindings, at which point herdr keeps the action and
        # disables this command with a config diagnostic rather than an error.
        # The rarer of the two actions sits here for that reason.
        programs.herdr.settings.keys.command = lib.mkAfter [
          {
            key = "prefix+d";
            type = "popup";
            command = "${reviewrPopup}";
            width = "90%";
            height = "90%";
            description = "reviewr: open the diff as a large popup";
          }
          {
            key = "prefix+shift+d";
            type = "plugin_action";
            command = "persiyanov.reviewr.toggle";
            description = "reviewr: toggle the diff pane as a split";
          }
        ];
      })

      (lib.mkIf cfg.usagebar.enable {
        # Preserve the complete sidebar experience for existing consumers while
        # keeping its layout and agent identity owned outside usagebar.
        programs.herdr.agentDisplay.enable = lib.mkDefault true;

        programs.herdr.plugins.usagebar = {
          id = "usagebar";
          # An overlay rather than a sibling in the `let` above, because Claude
          # Code's statusLine — the only route to its rate limits — is configured
          # from system scope, which cannot see a home-manager binding.
          package = pkgs.herdr-usagebar;
        };

        # prefix+u for "usage". The limits pane is on-demand — nothing surfaces
        # it without an explicit invocation — so with no bind the plugin looks
        # inert even while it is collecting fine.
        programs.herdr.settings.keys.command = lib.mkAfter [
          {
            key = "prefix+u";
            type = "plugin_action";
            command = "usagebar.open-limits";
            description = "Agent Usage: open the limits pane";
          }
        ];

      })

      (lib.mkIf cfg.splits.enable {
        programs.herdr.plugins.splits = {
          id = "herdr-splits";
          package = herdr-splits;
        };

        # The plugin ships the actions; the keys that reach them live in herdr's
        # own config. Ctrl+hjkl matches the tmux and Neovim bindings so the three
        # layers present one chord.
        programs.herdr.settings.keys.command = lib.mkAfter (
          lib.mapAttrsToList
            (key: dir: {
              inherit key;
              type = "plugin_action";
              command = "herdr-splits.nav-${dir}";
              description = "Navigate ${dir} (Neovim/herdr/tmux)";
            })
            {
              "ctrl+h" = "left";
              "ctrl+j" = "down";
              "ctrl+k" = "up";
              "ctrl+l" = "right";
            }
        );
      })
    ]
  );
}
