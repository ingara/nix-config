{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.herdr;
  summaryCfg = cfg.agentSummary;
  homePrefix = "${config.home.homeDirectory}/";
  # Expanded at run time so every account on a host shares one plugin build.
  shellPath =
    path:
    if lib.hasPrefix homePrefix path then
      ''"$HOME"/${lib.escapeShellArg (lib.removePrefix homePrefix path)}''
    else
      lib.escapeShellArg path;

  agentSummary = pkgs.writeShellApplication {
    name = "herdr-agent-summary";
    runtimeInputs = [
      cfg.package
      pkgs.coreutils
      pkgs.findutils
      pkgs.flock
      pkgs.gnugrep
      pkgs.jq
    ];
    text = ''
      worker_prefixes=${lib.escapeShellArg (builtins.toJSON cfg.agentDisplay.roles.workerPrefixes)}
      interval=${toString summaryCfg.interval}
      model=${lib.escapeShellArg summaryCfg.model}
      model_timeout=${toString summaryCfg.timeout}
      max_concurrent=${toString summaryCfg.maxConcurrent}
      claude_bin=${lib.escapeShellArg (lib.getExe summaryCfg.claudePackage)}
      claude_config_dir=${shellPath summaryCfg.claudeConfigDir}
      omp_sessions_dir=${shellPath summaryCfg.ompSessionsDir}
    ''
    + builtins.readFile ./herdr-agent-summary.sh;
  };

  manifest = (pkgs.formats.toml { }).generate "herdr-agent-summary.toml" {
    id = "local.agent-summary";
    name = "Agent Summary";
    version = "1.0.0";
    min_herdr_version = "0.9.5";
    description = "Shows a model-written line describing what each agent is working on";
    platforms = [
      "linux"
      "macos"
    ];

    # Herdr does not restore metadata tokens after a server restart.
    startup = [
      {
        command = [
          (lib.getExe agentSummary)
          "--startup"
        ];
      }
    ];

    actions = [
      {
        id = "refresh";
        title = "Refresh agent summaries";
        contexts = [ "pane" ];
        command = [
          (lib.getExe agentSummary)
          "--startup"
        ];
      }
      {
        id = "clear";
        title = "Clear agent summaries";
        description = "One-shot cleanup; enabled event hooks can repopulate the summaries";
        contexts = [ "pane" ];
        command = [
          (lib.getExe agentSummary)
          "--clear"
        ];
      }
    ];

    events =
      map
        (on: {
          inherit on;
          command = [
            (lib.getExe agentSummary)
            "--event"
          ];
        })
        [
          "pane.agent_detected"
          "pane.agent_status_changed"
        ];
  };

  plugin =
    pkgs.runCommand "herdr-agent-summary-plugin-1.0.0"
      {
        nativeBuildInputs = [
          pkgs.flock
          pkgs.jq
        ];
      }
      ''
        ${lib.getExe pkgs.bashNonInteractive} ${./herdr-agent-summary-test.sh} \
          ${lib.getExe agentSummary} ${lib.getExe pkgs.bashNonInteractive}

        mkdir -p "$out/bin"
        ln -s ${lib.getExe agentSummary} "$out/bin/herdr-agent-summary"
        cp ${manifest} "$out/herdr-plugin.toml"
      '';
in
{
  options.programs.herdr.agentSummary = {
    enable = lib.mkEnableOption ''
      model-written one-line summaries of what each agent is working on, as the
      `agent_summary` and `agent_summary_stale` pane metadata tokens. Agents
      named with an `agentDisplay.roles.workerPrefixes` prefix are skipped. Only
      Claude Code and OMP transcripts are read. Excerpts of them (recent
      requests, replies and tool calls) are sent to the model through
      `claude -p` with the host's existing Claude login'';
    interval = lib.mkOption {
      type = lib.types.ints.between 30 86400;
      default = 180;
      description = ''
        Seconds between summary refreshes while an agent is working. A refresh
        calls the model only when the transcript grew or the latest request
        changed since the last summary.
      '';
    };
    timeout = lib.mkOption {
      type = lib.types.ints.between 5 600;
      default = 60;
      description = "Seconds before a model call is abandoned and the previous summary kept.";
    };
    model = lib.mkOption {
      type = lib.types.str;
      default = "haiku";
      description = "Model passed to `claude --model`.";
    };
    maxConcurrent = lib.mkOption {
      type = lib.types.ints.between 1 8;
      default = 2;
      description = "Model calls allowed to run at once across all panes.";
    };
    claudePackage = lib.mkOption {
      type = lib.types.package;
      default = inputs.claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
      defaultText = lib.literalExpression "inputs.claude-code-nix.packages.\${system}.claude-code";
      description = "Claude Code package whose `claude -p` writes the summaries.";
    };
    claudeConfigDir = lib.mkOption {
      type = lib.types.str;
      default =
        cfg.integrations.claude.environment.CLAUDE_CONFIG_DIR or "${config.home.homeDirectory}/.claude";
      defaultText = lib.literalExpression ''
        config.programs.herdr.integrations.claude.environment.CLAUDE_CONFIG_DIR
          or "''${config.home.homeDirectory}/.claude"
      '';
      description = ''
        Claude Code configuration directory, used for its login and to find
        Claude Code transcripts. The Herdr server environment may not carry
        `CLAUDE_CONFIG_DIR`, so it is passed explicitly.
      '';
    };
    ompSessionsDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.omp/agent/sessions";
      defaultText = lib.literalExpression ''"''${config.home.homeDirectory}/.omp/agent/sessions"'';
      description = ''
        Directory OMP transcripts must resolve under. `PI_CODING_AGENT_DIR` in
        the Herdr server environment overrides it with its `sessions`
        subdirectory.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && cfg.package != null && summaryCfg.enable) {
    assertions = [
      {
        assertion = lib.versionAtLeast cfg.package.version "0.9.5";
        message = "programs.herdr.agentSummary requires Herdr 0.9.5 or newer";
      }
    ];

    programs.herdr.plugins.agent-summary = {
      id = "local.agent-summary";
      package = plugin;
    };
  };
}
