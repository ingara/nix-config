{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.herdr;
  colors = config.lib.stylix.colors.withHashtag;
  marks = [
    {
      mark = "▶";
      fg = colors.base0E;
      leadBold = true;
    }
    {
      mark = "!";
      fg = colors.base08;
      leadBold = true;
    }
    {
      mark = "✓";
      fg = colors.base0B;
      leadBold = false;
    }
    {
      mark = "–";
      fg = colors.base04;
      leadBold = false;
    }
    {
      mark = "?";
      fg = colors.base04;
      leadBold = false;
    }
    {
      mark = "⋯";
      fg = colors.base04;
      leadBold = false;
    }
    {
      mark = "◆";
      fg = colors.base0D;
      leadBold = false;
    }
  ];
  stateRules =
    role:
    lib.concatMap (
      state:
      map
        (indent: {
          contains = "​${indent}${state.mark} ";
          fg =
            if role == "lead" && state.mark == "–" then
              colors.base05
            else if role == "lead" && state.mark == "◆" then
              colors.base0D
            else if role == "worker" && state.mark == "✓" then
              colors.base04
            else
              state.fg;
          bold = role == "lead" && state.leadBold;
        })
        (
          if role == "lead" then
            [
              "  "
              "    "
            ]
          else
            [
              "      "
              "        "
            ]
        )
    ) marks;
  styledRow = token: fg: rules: {
    inherit token fg;
    bold = false;
    inherit rules;
  };
  agentRows = [
    [
      {
        token = "$agent_repository_header";
        fg = colors.base03;
        bold = false;
      }
    ]
    [
      {
        token = "$agent_workspace_header";
        fg = colors.base04;
        bold = false;
      }
    ]
    (map (entry: styledRow ("$" + entry.token) entry.fg (stateRules entry.role)) [
      {
        token = "agent_lead";
        fg = colors.base05;
        role = "lead";
      }
      {
        token = "agent_worker";
        fg = colors.base04;
        role = "worker";
      }
      {
        token = "agent_worker_quiet";
        fg = colors.base04;
        role = "worker";
      }
    ])
  ]
  ++ lib.optional (cfg.agentDisplay.titleRows == "all") [
    {
      token = "$agent_title";
      fg = colors.base03;
      bold = false;
    }
  ]
  ++ lib.optional (cfg.agentDisplay.groupGap == "repositories") [ "$agent_group_gap" ];
  ruleCountWithinLimit = lib.all (
    row: lib.all (token: !(builtins.isAttrs token) || builtins.length (token.rules or [ ]) <= 16) row
  ) agentRows;

  agentDisplay = pkgs.writeShellApplication {
    name = "herdr-agent-display";
    runtimeInputs = [
      cfg.package
      pkgs.jq
    ];
    text = ''
      lead_prefixes=${lib.escapeShellArg (builtins.toJSON cfg.agentDisplay.roles.leadPrefixes)}
      worker_prefixes=${lib.escapeShellArg (builtins.toJSON cfg.agentDisplay.roles.workerPrefixes)}
      plain_leads=${lib.escapeShellArg (builtins.toJSON cfg.agentDisplay.roles.plainLeads)}
      title_rows=${lib.escapeShellArg cfg.agentDisplay.titleRows}
      group_gap=${lib.escapeShellArg cfg.agentDisplay.groupGap}
    ''
    + builtins.readFile ./herdr-agent-display.sh;
  };

  manifest = (pkgs.formats.toml { }).generate "herdr-agent-display.toml" {
    id = "local.agent-display";
    name = "Agent Display";
    version = "7.0.0";
    min_herdr_version = "0.9.0";
    description = "Shows grouped agent roles, attention states, and optional terminal titles";
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
        command = [
          (lib.getExe agentDisplay)
          "--all"
        ];
      }
      # For durable cleanup, disable or unlink the plugin before running the
      # packaged command with --clear; enabled event hooks can restore tokens.
      {
        id = "clear";
        title = "Clear agent display metadata";
        description = "One-shot cleanup; enabled event hooks can repopulate the metadata";
        contexts = [ "pane" ];
        command = [
          (lib.getExe agentDisplay)
          "--clear"
        ];
      }
    ];

    # Herdr emits only pane.updated for agent.rename, which plugin manifests
    # cannot subscribe to. Focus is the supported refresh path for that case.
    events =
      map
        (on: {
          inherit on;
          command = [
            (lib.getExe agentDisplay)
            "--all"
          ];
        })
        [
          "workspace.renamed"
          "workspace.updated"
          "workspace.moved"
          "workspace.reordered"
          "tab.renamed"
          "tab.moved"
          "tab.closed"
          "pane.closed"
          "pane.agent_detected"
          "pane.agent_status_changed"
          "pane.focused"
          "pane.moved"
        ];
  };

  plugin =
    pkgs.runCommand "herdr-agent-display-plugin-7.0.0"
      {
        nativeBuildInputs = [ pkgs.jq ];
      }
      ''
        ${lib.getExe pkgs.bashNonInteractive} ${./herdr-agent-display-test.sh} \
          ${lib.getExe agentDisplay} ${lib.getExe pkgs.bashNonInteractive}

        mkdir -p "$out/bin"
        ln -s ${lib.getExe agentDisplay} "$out/bin/herdr-agent-display"
        cp ${manifest} "$out/herdr-plugin.toml"
      '';
in
{
  options.programs.herdr.agentDisplay = {
    enable = lib.mkEnableOption "grouped agent roles and status marks in the sidebar";
    roles = {
      leadPrefixes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Name prefixes displayed as leads.";
      };
      workerPrefixes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Name prefixes displayed as workers.";
      };
      plainLeads = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Lead names that use ordinary status marks instead of wait marks.";
      };
    };
    titleRows = lib.mkOption {
      type = lib.types.enum [
        "none"
        "all"
      ];
      default = "none";
      description = "Whether every agent has a stripped terminal-title row.";
    };
    groupGap = lib.mkOption {
      type = lib.types.enum [
        "none"
        "repositories"
      ];
      default = "none";
      description = "Whether to separate repository families with a blank row.";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.package != null && cfg.agentDisplay.enable) {
    assertions = [
      {
        assertion = lib.versionAtLeast cfg.package.version "0.9.0";
        message = "programs.herdr.agentDisplay requires Herdr 0.9.0 or newer";
      }
      {
        assertion = ruleCountWithinLimit;
        message = "programs.herdr.agentDisplay sidebar tokens allow at most 16 rules each";
      }
    ];

    programs.herdr.plugins.agent-display = {
      id = "local.agent-display";
      package = plugin;
    };

    programs.herdr.settings.theme.custom.active_row_bg = colors.base02;
    programs.herdr.settings.ui = {
      agent_panel_sort = "spaces";
      sidebar_width = 36;
      sidebar_max_width = 36;
      sidebar.agents = {
        row_gap = 0;
        rows = agentRows;
      };
    };
  };
}
