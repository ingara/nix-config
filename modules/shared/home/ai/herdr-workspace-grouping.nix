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
    ];
    text = builtins.readFile ./herdr-workspace-grouping.sh;
  };

  manifest = (pkgs.formats.toml { }).generate "herdr-workspace-grouping.toml" {
    id = "local.workspace-grouping";
    name = "Workspace Grouping";
    version = "1.0.0";
    min_herdr_version = "0.9.5";
    description = "Moves a new worktree workspace next to the other workspaces of its repository";
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
    pkgs.runCommand "herdr-workspace-grouping-plugin-1.0.0"
      {
        nativeBuildInputs = [
          pkgs.flock
          pkgs.jq
          pkgs.socat
        ];
      }
      ''
        ${lib.getExe pkgs.bashNonInteractive} ${./herdr-workspace-grouping-test.sh} \
          ${lib.getExe workspaceGrouping} ${lib.getExe pkgs.bashNonInteractive}

        mkdir -p "$out/bin"
        ln -s ${lib.getExe workspaceGrouping} "$out/bin/herdr-workspace-grouping"
        cp ${manifest} "$out/herdr-plugin.toml"
      '';
in
{
  options.programs.herdr.workspaceGrouping.enable = lib.mkEnableOption ''
    moving each new workspace with worktree provenance, once when Herdr creates
    it, to the end of the first contiguous run of other workspaces from the same
    repository'';

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
