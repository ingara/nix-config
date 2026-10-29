{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.herdr;

  workspaceGrouping = pkgs.writeShellApplication {
    name = "herdr-workspace-grouping";
    runtimeInputs = [
      cfg.package
      pkgs.coreutils
      pkgs.flock
      pkgs.jq
      pkgs.socat
      (pkgs.callPackage ./herdr-workspace-repos.nix { })
    ];
    text = builtins.readFile ./herdr-workspace-grouping.sh;
  };

  manifest = (pkgs.formats.toml { }).generate "herdr-workspace-grouping.toml" {
    id = "local.workspace-grouping";
    name = "Workspace Grouping";
    version = "1.1.0";
    min_herdr_version = "0.9.5";
    description = "Moves a new repository workspace next to the other workspaces of its repository";
    platforms = [
      "linux"
      "macos"
    ];

    # Only creation is handled, so later manual reordering is left alone.
    events = [
      {
        on = "workspace.created";
        command = [ (lib.getExe workspaceGrouping) ];
      }
    ];
  };

  plugin =
    pkgs.runCommand "herdr-workspace-grouping-plugin-1.1.0"
      {
        nativeBuildInputs = [
          pkgs.flock
          pkgs.git
          pkgs.jq
          pkgs.socat
        ];
      }
      ''
        export HOME="$TMPDIR/home"
        mkdir -p "$HOME"
        run_fixtures() {
          ${lib.getExe pkgs.bashNonInteractive} ${./herdr-workspace-grouping-test.sh} \
            ${lib.getExe workspaceGrouping} ${lib.getExe pkgs.bashNonInteractive} \
            ${./herdr-workspace-repos-fixture.sh}
        }
        # Only a fake server failure (75) is retried; a plugin failure stands.
        run_fixtures || {
          status=$?
          [ "$status" -eq 75 ] || exit "$status"
          echo "Rerunning the workspace grouping fixtures after a fake server failure."
          run_fixtures
        }

        mkdir -p "$out/bin"
        ln -s ${lib.getExe workspaceGrouping} "$out/bin/herdr-workspace-grouping"
        cp ${manifest} "$out/herdr-plugin.toml"
      '';
in
{
  options.programs.herdr.workspaceGrouping.enable = lib.mkEnableOption ''
    moving each new repository workspace, once when Herdr creates it, to the end
    of the first contiguous run of other workspaces from the same repository.
    Generic workspaces use the first pane in layout order of the first listed
    tab; unresolved workspaces stay put. Repository resolution failure or
    timeout skips placement and logs the affected workspace'';

  config = lib.mkIf (cfg.enable && cfg.package != null && cfg.workspaceGrouping.enable) {
    assertions = [
      {
        assertion = lib.versionAtLeast cfg.package.version "0.9.5";
        message = "programs.herdr.workspaceGrouping requires Herdr 0.9.5 or newer";
      }
    ];

    programs.herdr.plugins.workspace-grouping = {
      id = "local.workspace-grouping";
      package = plugin;
    };
  };
}
