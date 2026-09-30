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

  reviewrAssets = {
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-gf1BcymDZ8D1LZaeE7LB7vj1Qx2CUFNJegVs7bjR8mE=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-r2vbg4/yvVC3a8NnkxVPt/OzUMP4BFp5LVjkSX8blTA=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-8c3hLNYiSK03XQz2i44WCVAD+ul/I62jQZmmtl3aX/4=";
    };
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-P1mWvp+9ie3LlN5MMlZIPkpsopxA+YHhUFVBWQtYKX8=";
    };
  };
  reviewrAsset =
    reviewrAssets.${pkgs.stdenv.hostPlatform.system}
      or (throw "herdr-reviewr: unsupported system ${pkgs.stdenv.hostPlatform.system}");

  # Untagged upstream — no releases to track, so this is a dated commit pin:
  # bump it deliberately, and don't expect a version string to follow along.
  resurrectPin = {
    rev = "5afa6755d4f35c62c7522ba4fd04922d1ac69602";
    date = "2026-08-24";
    hash = "sha256-t4HCaLy2yWkeuvDovFTRdG0jQvlyKf5Z+u5UIU3xvts=";
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
    nativeBuildInputs = [ pkgs.makeWrapper ];

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r . "$out/"
      substituteInPlace "$out/herdr-plugin.toml" \
        --replace-fail '"node"' '"${lib.getExe pkgs.nodejs}"' \
        --replace-fail '"bash"' '"${lib.getExe pkgs.bashNonInteractive}"'
      for script in "$out"/*.sh; do
        substituteInPlace "$script" \
          --replace-fail '#!/usr/bin/env bash' \
          '#!${lib.getExe pkgs.bashNonInteractive}'
        wrapProgram "$script" \
          --prefix PATH : ${
            lib.makeBinPath [
              pkgs.coreutils
              pkgs.fzf
              pkgs.gnused
              pkgs.jq
              pkgs.nodejs
            ]
          }
      done
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
  herdr-reviewr = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "herdr-reviewr";
    version = "0.36.2";

    src = pkgs.fetchFromGitHub {
      owner = "persiyanov";
      repo = "herdr-reviewr";
      tag = "v${finalAttrs.version}";
      hash = "sha256-bQiIj9HpkwCtoR5SoyDah0w/f15fUVtSqxMZ3zxLOy8=";
    };

    binary = pkgs.fetchurl {
      url = "https://github.com/persiyanov/herdr-reviewr/releases/download/v${finalAttrs.version}/herdr-reviewr-${reviewrAsset.target}.tar.gz";
      inherit (reviewrAsset) hash;
    };

    nativeBuildInputs = [
      pkgs.gnutar
      pkgs.gzip
    ];
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin"
      tar -xzf ${finalAttrs.binary} -C "$TMPDIR"
      install -m755 "$TMPDIR/herdr-reviewr" "$out/bin/herdr-reviewr"

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

      runHook postInstall
    '';

    meta = {
      description = "Review an agent's diff beside the chat and send line comments back";
      homepage = "https://github.com/persiyanov/herdr-reviewr";
      license = lib.licenses.mit;
      mainProgram = "herdr-reviewr";
      platforms = builtins.attrNames reviewrAssets;
      sourceProvenance = with lib.sourceTypes; [
        binaryNativeCode
        fromSource
      ];
    };
  });

  # Ctrl+hjkl across nvim splits, herdr panes and — with the patch below — an
  # outer tmux. Upstream assumes herdr is the outermost multiplexer; running it
  # inside tmux adds a third layer it has no concept of.
  herdr-splits = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "herdr-splits";
    version = "0.5.3";

    src = pkgs.fetchFromGitHub {
      owner = "lmilojevicc";
      repo = "herdr-splits.nvim";
      tag = "v${finalAttrs.version}";
      hash = "sha256-7rHAPSjd2n16FGOcqI/1KNHl1yCmMOVVwiJl/eEU9n8=";
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

        # Keep review panes opt-in when creating or opening worktrees.
        xdg.configFile."herdr/plugins/config/persiyanov.reviewr/config.toml".source =
          (pkgs.formats.toml { }).generate "herdr-reviewr-config.toml"
            {
              auto_open = false;
              toggle_placement = "tab";
            };

        # prefix+d for "diff". Prefix-gated rather than a bare chord so the
        # focused pane can't swallow it, and plain ASCII rather than
        # `ctrl+shift+*`, which rides the kitty keyboard protocol and may not
        # survive an SSH hop — herdr is driven over `--remote` here.
        programs.herdr.settings.keys.command = lib.mkAfter [
          {
            key = "prefix+d";
            type = "plugin_action";
            command = "persiyanov.reviewr.toggle";
            description = "reviewr: toggle the diff tab";
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
