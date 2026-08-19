{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.herdr;

  agentDisplay = pkgs.writeShellApplication {
    name = "herdr-agent-display";
    runtimeInputs = [
      cfg.package
      pkgs.jq
    ];
    text = builtins.readFile ./herdr-agent-display.sh;
  };

  manifest = (pkgs.formats.toml { }).generate "herdr-agent-display.toml" {
    id = "local.agent-display";
    name = "Agent Display";
    version = "1.0.0";
    min_herdr_version = "0.7.5";
    description = "Shows a named agent together with its canonical harness";
    platforms = [
      "linux"
      "macos"
    ];

    startup = [
      {
        command = [
          (lib.getExe agentDisplay)
          "--all"
        ];
      }
    ];

    actions = [
      {
        id = "refresh";
        title = "Refresh agent display";
        contexts = [ "pane" ];
        command = [ (lib.getExe agentDisplay) ];
      }
    ];

    # Herdr emits only pane.updated for agent.rename, which plugin manifests
    # cannot subscribe to. Focus and status changes provide the supported refresh.
    events =
      map
        (on: {
          inherit on;
          command = [ (lib.getExe agentDisplay) ];
        })
        [
          "pane.agent_detected"
          "pane.agent_status_changed"
          "pane.focused"
        ];
  };

  plugin = pkgs.runCommand "herdr-agent-display-plugin-1.0.0" { } ''
    ${lib.getExe pkgs.bashNonInteractive} ${./herdr-agent-display-test.sh} \
      ${lib.getExe agentDisplay} ${lib.getExe pkgs.bashNonInteractive}

    mkdir -p "$out/bin"
    ln -s ${lib.getExe agentDisplay} "$out/bin/herdr-agent-display"
    cp ${manifest} "$out/herdr-plugin.toml"
  '';
in
{
  options.programs.herdr.agentDisplay.enable = lib.mkEnableOption ''
    stable agent-list labels that show a friendly agent name with its canonical
    harness, independently of usage-meter plugins
  '';

  config = lib.mkIf (cfg.enable && cfg.package != null && cfg.agentDisplay.enable) {
    programs.herdr.plugins.agent-display = {
      id = "local.agent-display";
      package = plugin;
    };

    # The display row survives without usagebar. Herdr drops unresolved custom
    # tokens, so `$limit` and `$context` disappear cleanly when it is disabled.
    programs.herdr.settings.ui.sidebar.agents = {
      row_gap = 0;
      rows = [
        [
          "state_icon"
          "workspace"
          "tab"
        ]
        [
          "$agent_display"
          "$limit"
        ]
        [ "$context" ]
      ];
    };
  };
}
