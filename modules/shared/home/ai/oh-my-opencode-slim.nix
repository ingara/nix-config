# oh-my-opencode-slim — declarative install
#
# Replaces the upstream `bunx oh-my-opencode-slim install` flow with a fully
# nix-managed install. The installer mutates five pieces of state:
#
#   1. opencode.json `plugin` array — adds slim's npm entry
#   2. opencode.json `agent.{explore,general}.disable` — slim wants to own
#      delegation, so the upstream defaults are disabled
#   3. opencode.json `lsp` — enabled by default for slim's LSP-aware tools
#   4. tui.json `plugin` — adds the version-badge marker for the status bar
#   5. ~/.config/opencode/oh-my-opencode-slim.json — the preset config
#      (provider/model per agent)
#
# (1)–(4) are deep-path additions to `programs.opencode.{settings,tui}` that
# merge with the whole-attrset definition in `./opencode.nix` and the stylix
# target in `programs.opencode.tui.theme`.
#
# (5) is rendered from a nix attrset via `xdg.configFile`; it's a read-only
# symlink to the nix store. Tweak the preset by editing this file and
# rebuilding, not by editing the live JSON.
#
# Applied on every host that imports the opencode module — both workstation
# and server profiles. Slim is interactive-orchestration-shaped but it's
# just an opencode plugin; nothing about it breaks in non-interactive use,
# and a self-hosted agent on a homelab server could plausibly benefit from
# delegation.
#
# Plugin version is pinned (`oh-my-opencode-slim@<version>`) so opencode's
# runtime resolver doesn't drift. Bump by changing `slimVersion` below.
#
# Drift surfaces:
#   - npm package:   xh GET https://registry.npmjs.org/oh-my-opencode-slim/latest | jq -r .version
#   - model IDs:     https://models.dev (openai catalog)
#
# Slim release notes can change agent personas, bundled skill/MCP names, or the
# preset schema — read the changelog when bumping `slimVersion`.
#
# The plugin npm package itself is fetched by opencode's bundled runtime on
# first start; no external bun/npm needed. The `~/.config/opencode/{package,
# package-lock,node_modules}` artifacts are managed by opencode, not by nix.
{ lib, ... }:

let
  slimVersion = "2.2.15";
  slimPluginEntry = "oh-my-opencode-slim@${slimVersion}";

  # Slim preset config (~/.config/opencode/oh-my-opencode-slim.json).
  # One preset ships: chatgpt, on the subscription rather than a metered API
  # key. Register it with `opencode auth login -p openai` and pick the ChatGPT
  # OAuth method (browser or headless); the credential lands in opencode's own
  # auth store, which is imperative state this module does not manage.
  #
  # `skills` and `mcps` are slim's per-agent capability scoping:
  #   - "*"        — all available (auto-discovered from ~/.config/opencode
  #                  and project workdir)
  #   - "!<name>"  — exclude
  #   - []         — none
  #
  # MCP names — from our own opencode config plus the one that slim bundles
  # and auto-registers at startup. Our own (see ./opencode.nix and
  # ../../../../modules/ai/opencode-mcp.nix):
  #   - context7    — library docs (librarian-scoped)
  #   - obsidian    — note vault (not wired to any specialist by default)
  #   - ingar       — private MCPJungle gateway on a homelab server
  #                   (aggregates fetcher etc.; useful for librarian-style
  #                   page fetches over tailnet)
  # Slim-bundled (registered by the plugin itself, no config needed):
  #   - gh_grep     — GitHub code search
  # OpenCode's built-in websearch tool uses Exa and is enabled below.
  #
  # Model IDs come from models.dev (`openai` models catalog) and keep its
  # dotted spelling. Tiering follows the roles: the flagship for the agents
  # that plan or judge, the cheap tier for the high-volume search-and-patch
  # ones, and the mid tier where output shape matters more than depth.
  slimConfig = {
    "$schema" = "https://unpkg.com/oh-my-opencode-slim@${slimVersion}/oh-my-opencode-slim.schema.json";
    preset = "chatgpt";

    # Background agents are the default workflow in slim v2. "auto" opens each
    # specialist in a dedicated tmux/zellij/Herdr pane when one is detected, and
    # no-ops otherwise (non-interactive server runs).
    multiplexer.type = "auto";

    # Nix owns the pinned version (`slimVersion` above); stop slim from
    # self-updating its plugin in the background and fighting the pin. Default
    # is true (background auto-install); flip to notification-only.
    autoUpdate = false;

    presets = {
      chatgpt = {
        orchestrator = {
          model = "openai/gpt-5.6-sol";
          skills = [ "*" ];
          mcps = [
            "*"
            "!context7"
          ];
        };
        oracle = {
          model = "openai/gpt-5.6-sol";
          variant = "high";
          skills = [ "simplify" ];
          mcps = [ ];
        };
        council = {
          model = "openai/gpt-5.6-sol";
          variant = "high";
          skills = [ ];
          mcps = [ ];
        };
        librarian = {
          model = "openai/gpt-5.6-luna";
          skills = [ ];
          mcps = [
            "context7"
            "gh_grep"
            "ingar"
          ];
        };
        explorer = {
          model = "openai/gpt-5.6-luna";
          skills = [ ];
          mcps = [ ];
        };
        designer = {
          model = "openai/gpt-5.6-terra";
          variant = "medium";
          skills = [ ];
          mcps = [ ];
        };
        fixer = {
          model = "openai/gpt-5.6-luna";
          skills = [ ];
          mcps = [ ];
        };
      };
    };
  };
in
{
  # Slim's interactive installer enables Exa; declarative installs must do it
  # here.
  home.sessionVariables.OPENCODE_ENABLE_EXA = "1";

  programs.opencode = {
    settings = {
      # Pinned plugin entry — opencode's runtime resolves and caches under
      # ~/.config/opencode/node_modules on first start.
      plugin = [ slimPluginEntry ];

      # Slim wires LSP-aware tools (lsp_rename, lsp_goto_definition,
      # lsp_find_references, lsp_diagnostics). Cheap to leave on.
      lsp = true;

      # Slim's Orchestrator owns delegation; opencode's built-in `explore`
      # and `general` agents would compete with Explorer/Orchestrator.
      agent = {
        explore.disable = true;
        general.disable = true;
      };
    };

    # TUI status-line version badge. Stylix already sets `tui.theme`; this
    # merges into the same attrset.
    tui.plugin = [ slimPluginEntry ];
  };

  xdg.configFile."opencode/oh-my-opencode-slim.json".text = lib.generators.toJSON { } slimConfig;
}
