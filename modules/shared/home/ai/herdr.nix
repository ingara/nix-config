{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.herdr;
  integrationNames = builtins.attrNames cfg.integrations;
  integrationType = lib.types.submodule {
    options = {
      directories = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Directories that must exist before installing the integration.";
      };
      environment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Environment variables used by the integration installer.";
      };
    };
  };
  envArgs =
    environment: lib.mapAttrsToList (name: value: lib.escapeShellArg "${name}=${value}") environment;
  installCommand = name: integration: ''
    ${lib.optionalString (integration.directories != [ ]) ''
      ${pkgs.coreutils}/bin/mkdir -p ${
        lib.concatMapStringsSep " " lib.escapeShellArg integration.directories
      }
    ''}
    ${pkgs.coreutils}/bin/env ${lib.concatStringsSep " " (envArgs integration.environment)} "$herdr_bin" integration install ${lib.escapeShellArg name}
    integration_status="$(${pkgs.coreutils}/bin/env ${lib.concatStringsSep " " (envArgs integration.environment)} "$herdr_bin" integration status)"
    if ! ${pkgs.gnugrep}/bin/grep -q ${lib.escapeShellArg "^${name}: current"} <<<"$integration_status"; then
      echo "Herdr ${name} integration did not verify as current" >&2
      printf '%s\n' "$integration_status" >&2
      exit 1
    fi
  '';

  pluginNames = builtins.attrNames cfg.plugins;
  pluginType = lib.types.submodule (
    { name, ... }:
    {
      options = {
        package = lib.mkOption {
          type = lib.types.package;
          description = ''
            Derivation whose output *is* the plugin root — `herdr-plugin.toml` at
            its top level. Linked in place, so it must be self-contained: herdr
            skips a plugin's `[[build]]` steps on `link`, and the store path is
            read-only.
          '';
        };
        id = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = ''
            Plugin id, which must equal the `id` field of the plugin's
            `herdr-plugin.toml` — it is the key the registry is reconciled on. A
            mismatch is caught at activation, not evaluation.
          '';
        };
      };
    }
  );
  reconcilePlugin =
    _name: plugin:
    "reconcile_plugin ${lib.escapeShellArg plugin.id} ${lib.escapeShellArg "${plugin.package}"}";

  # Reconciles the registry (~/.config/herdr/plugins.json) through the CLI rather
  # than writing it: it is lock-guarded, atomically rewritten by the running
  # server, and its schema is herdr-internal.
  #
  # Reconciles on every activation with no follow-up step, including across a
  # herdr upgrade. That case needs care: a bump activates a new client while the
  # old server is still running, and the server refuses a newer protocol. The
  # obvious response — skip and retry next activation — does not work, because
  # home-manager only activates when the generation changes, so the switch after
  # restarting herdr is a no-op and the retry never comes.
  #
  # Instead, fall back to reconciling *offline*: with no server reachable,
  # `plugin link` writes ~/.config/herdr/plugins.json directly, and the server
  # reads that file, so the outcome is identical to the online path — it simply
  # doesn't need the restart to have happened yet. Verified: an offline link
  # lands in the real registry and a running server picks it up without a reload.
  #
  # Exposed on PATH as well, so a reconcile can be forced without a switch.
  herdrRelink = pkgs.writeShellApplication {
    name = "herdr-relink";
    runtimeInputs = [
      cfg.package
      pkgs.jq
      pkgs.coreutils
    ];
    text = ''
      # A healthy read puts the registry on stdout; errors arrive as JSON on
      # stderr with a non-zero exit. Keep the streams apart so a stray warning on
      # stderr can't corrupt the parsed registry.
      herdr_err="$(mktemp)"
      offline_dir="$(mktemp -d)"
      trap 'rm -rf "$herdr_err" "$offline_dir"' EXIT

      online=1
      if ! registry_json="$(herdr plugin list --json 2>"$herdr_err")"; then
        code="$(jq -r '.error.code // empty' <"$herdr_err" 2>/dev/null || true)"
        if [[ "$code" != "protocol_mismatch" ]]; then
          echo "herdr: could not read the plugin registry:" >&2
          cat "$herdr_err" >&2
          exit 0
        fi
        # Point at a socket that cannot exist. herdr does not spawn a server to
        # satisfy it, so this selects the offline path rather than starting one.
        online=0
        export HERDR_SOCKET_PATH="$offline_dir/absent.sock"
        if ! registry_json="$(herdr plugin list --json 2>"$herdr_err")"; then
          echo "herdr: could not read the plugin registry offline either:" >&2
          cat "$herdr_err" >&2
          exit 0
        fi
        echo "herdr: server predates this build; reconciling the registry offline." >&2
        echo "herdr: it takes effect for panes started after the next herdr restart." >&2
      fi

      # Every path returns 0 by default: a reconciliation problem is reported,
      # never fatal, so activation can call this without risking the switch.
      reconcile_plugin() {
        local id="$1" root="$2" current entry registered

        # `|| true` on every capture: the script runs under `set -e`, so an
        # unguarded failure here would abort the whole run — and by extension the
        # activation that calls it — despite this function's contract of degrading
        # one plugin rather than taking the switch down.
        current="$(jq -r --arg id "$id" \
          '.result.plugins[]? | select(.plugin_id == $id) | .plugin_root' \
          <<<"$registry_json" || true)"

        # The store path changes on every version bump, which is what makes
        # plugin_root a reliable idempotency key.
        if [[ "$current" == "$root" ]]; then
          return 0
        fi
        # `link` replaces an existing entry with the same id, so it covers both
        # "absent" and "registered at a stale root" — no unlink first. That
        # matters beyond tidiness: `unlink` has no offline fallback and fails
        # outright with no server running, whereas `link` does.
        if ! herdr plugin link "$root" >/dev/null 2>&1; then
          echo "herdr: could not link plugin '$id' from $root." >&2
          return 0
        fi

        entry="$(herdr plugin list --json 2>/dev/null \
          | jq -c --arg id "$id" '.result.plugins[]? | select(.plugin_id == $id)' || true)"

        registered=""
        if [[ -n "$entry" ]]; then
          registered="$(jq -r '.plugin_root // empty' <<<"$entry" 2>/dev/null || true)"
        fi
        if [[ "$registered" != "$root" ]]; then
          echo "herdr: plugin '$id' did not register at $root (got ''${registered:-nothing})." >&2
          echo "herdr: check that its herdr-plugin.toml declares id = \"$id\"." >&2
          return 0
        fi

        # Non-fatal manifest problems herdr records against the entry.
        jq -r --arg id "$id" \
          '.warnings[]? | "herdr: plugin warning [\($id)]: \(.)"' <<<"$entry" >&2 || true
      }

      ${lib.concatStringsSep "\n      " (lib.mapAttrsToList reconcilePlugin cfg.plugins)}

      # Applies most UI settings without restarting panes. Pointless when we went
      # offline — that server is the one refusing us — so only try when online.
      if [[ "$online" -eq 1 ]]; then
        herdr server reload-config >/dev/null 2>&1 || true
      fi
    '';
  };
in
{
  # Extends home-manager's own programs.herdr, which supplies enable/package and
  # the `settings` attrset it renders to $XDG_CONFIG_HOME/herdr/config.toml.
  # Redeclaring any of those here is a duplicate-option eval error.
  options.programs.herdr = {
    integrations = lib.mkOption {
      type = lib.types.attrsOf integrationType;
      default = { };
      description = "Agent integrations managed by Herdr.";
    };

    plugins = lib.mkOption {
      type = lib.types.attrsOf pluginType;
      default = { };
      description = ''
        Herdr plugins linked from the store instead of installed with
        `herdr plugin install`, which clones from GitHub and self-updates.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && cfg.package != null) (
    lib.mkMerge [
      # `herdr --remote` defaults to `--remote-keybindings local`, and the
      # profile the client ships to the server comes from
      # `Config::local_keybindings_profile_toml`, which drops every
      # `[[keys.command]]` entry — upstream's reason being that those commands
      # would run on the remote host. A remote attach therefore loses the whole
      # custom-command layer at once, and loses it silently: the keys do
      # nothing.
      #
      # `--remote-keybindings server` takes the server's map instead, whose
      # commands name paths that exist where they run. It swaps the *whole* map,
      # prefix and nav chords included — invisible while every herdr host is
      # configured from this flake, and the thing to remember when attaching to
      # one that isn't.
      #
      # A shell function rather than an alias because the flag is rejected
      # without `--remote`, so it cannot ride `herdr` itself; automatic rather
      # than left to the operator because the failure it prevents reads as a
      # broken keybind, not as a missing flag. A `writeShellScriptBin "herdr"`
      # would also cover what a shell function misses — non-interactive zsh, a
      # WM keybind, `ssh host herdr` — but home-manager already puts
      # `cfg.package` in `home.packages`, so a second `bin/herdr` needs
      # `lib.hiPrio` or an option wrapping the package. Not worth that while
      # `--remote` is only ever typed at a prompt.
      {
        programs.fish.functions.herdr = {
          description = "herdr, taking the server's keybindings on a remote attach";
          body = ''
            set -l remote 0
            set -l keybindings 0
            for arg in $argv
              switch $arg
                # herdr stops parsing here, so anything past it is the payload's.
                case --
                  break
                case --remote '--remote=*'
                  set remote 1
                case --remote-keybindings '--remote-keybindings=*'
                  set keybindings 1
              end
            end
            if test $remote -eq 1; and test $keybindings -eq 0
              command herdr --remote-keybindings server $argv
            else
              command herdr $argv
            end
          '';
        };

        programs.zsh.initContent = ''
          function herdr() {
            local arg remote=0 keybindings=0
            for arg in "$@"; do
              case $arg in
                # herdr stops parsing here, so anything past it is the payload's.
                --) break ;;
                --remote|--remote=*) remote=1 ;;
                --remote-keybindings|--remote-keybindings=*) keybindings=1 ;;
              esac
            done
            if (( remote && ! keybindings )); then
              command herdr --remote-keybindings server "$@"
            else
              command herdr "$@"
            fi
          }
        '';
      }

      (lib.mkIf (cfg.integrations != { }) {
        assertions = [
          {
            assertion = lib.all (name: builtins.match "[a-z0-9-]+" name != null) integrationNames;
            message = "programs.herdr integration names must match [a-z0-9-]+";
          }
          {
            assertion = lib.all (
              integration:
              lib.all (name: builtins.match "[A-Za-z_][A-Za-z0-9_]*" name != null) (
                builtins.attrNames integration.environment
              )
            ) (builtins.attrValues cfg.integrations);
            message = "programs.herdr integration environment keys must be valid variable names";
          }
        ];

        home.activation.installHerdrIntegrations = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          herdr_bin=${lib.escapeShellArg "${cfg.package}/bin/herdr"}

          if [[ -n "''${DRY_RUN_CMD:-}" ]]; then
            echo "Would install Herdr integrations: ${lib.concatStringsSep ", " integrationNames}"
          else
            ${lib.concatStringsSep "\n" (lib.mapAttrsToList installCommand cfg.integrations)}
          fi
        '';
      })

      (lib.mkIf (cfg.plugins != { }) {
        assertions = [
          {
            assertion = lib.all (plugin: builtins.match "[A-Za-z0-9._:-]+" plugin.id != null) (
              builtins.attrValues cfg.plugins
            );
            message = "programs.herdr plugin ids must match [A-Za-z0-9._:-]+";
          }
        ];

        home.packages = [ herdrRelink ];

        home.activation.linkHerdrPlugins = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          if [[ -n "''${DRY_RUN_CMD:-}" ]]; then
            echo "Would link Herdr plugins: ${lib.concatStringsSep ", " pluginNames}"
          else
            ${herdrRelink}/bin/herdr-relink
          fi
        '';
      })
    ]
  );
}
