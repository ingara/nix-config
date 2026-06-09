# oh-my-opencode-slim — declarative install
#
# Replaces the upstream `bunx oh-my-opencode-slim install` flow with a fully
# nix-managed install. The installer mutates four pieces of state:
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
#   - model IDs:     https://models.dev (anthropic + amazon-bedrock catalogs)
#
# Slim release notes can change agent personas, bundled skill names, or the
# preset schema — read the changelog when bumping `slimVersion`. Other
# variables in this file (provider IDs, MCP names) don't drift externally.
#
# The plugin npm package itself is fetched by opencode's bundled runtime on
# first start; no external bun/npm needed. The `~/.config/opencode/{package,
# package-lock,node_modules}` artifacts are managed by opencode, not by nix.
{ lib, ... }:

let
  slimVersion = "1.1.1";
  slimPluginEntry = "oh-my-opencode-slim@${slimVersion}";

  # --------------------------------------------------------------------------
  # Slim preset config (~/.config/opencode/oh-my-opencode-slim.json)
  # --------------------------------------------------------------------------
  # One preset ships: bedrock. The plain `anthropic` provider can't be
  # registered on this host — `opencode auth login anthropic` fails with
  # "Failed to load auth provider metadata from anthropic: fetch() URL is
  # invalid" (upstream issue). When/if that's fixed, add an `anthropic`
  # preset alongside `bedrock` and switch via `preset` below.
  #
  # `skills` and `mcps` are slim's per-agent capability scoping:
  #   - "*"        — all available (auto-discovered from ~/.config/opencode
  #                  and project workdir)
  #   - "!<name>"  — exclude
  #   - []         — none
  #
  # MCP names — from our own opencode config plus the two that slim bundles
  # and auto-registers at startup. Our own (see ./opencode.nix and
  # ../../../../modules/ai/opencode-mcp.nix):
  #   - context7    — library docs (librarian-scoped)
  #   - obsidian    — note vault (not wired to any specialist by default)
  #   - ingar       — private MCPJungle gateway on a homelab server
  #                   (aggregates fetcher etc.; useful for librarian-style
  #                   page fetches over tailnet)
  # Slim-bundled (registered by the plugin itself, no config needed):
  #   - websearch   — Exa-backed web search
  #   - grep_app    — GitHub code search
  #
  # Model IDs: opencode's amazon-bedrock provider routes via region-prefixed
  # inference-profile IDs. We use the `us.` prefix because that's the region
  # that's historically worked here (the `global.` cross-region profile has
  # had upstream issues). Switch to `eu.` / `au.` / `jp.` / `global.` if you
  # want to pin traffic elsewhere. IDs come from models.dev (`amazon-bedrock`
  # models catalog). Auth piggybacks on `AWS_BEARER_TOKEN_BEDROCK` (see
  # modules/aws-bedrock-bearer.nix).
  slimConfig = {
    "$schema" = "https://unpkg.com/oh-my-opencode-slim@${slimVersion}/oh-my-opencode-slim.schema.json";
    preset = "bedrock";
    presets = {
      bedrock = {
        orchestrator = {
          model = "amazon-bedrock/us.anthropic.claude-opus-4-6-v1";
          skills = [ "*" ];
          mcps = [
            "*"
            "!context7"
          ];
        };
        oracle = {
          model = "amazon-bedrock/us.anthropic.claude-opus-4-6-v1";
          variant = "high";
          skills = [ "simplify" ];
          mcps = [ ];
        };
        council = {
          model = "amazon-bedrock/us.anthropic.claude-opus-4-6-v1";
          variant = "high";
          skills = [ ];
          mcps = [ ];
        };
        librarian = {
          model = "amazon-bedrock/us.anthropic.claude-haiku-4-5-20251001-v1:0";
          skills = [ ];
          mcps = [
            "websearch"
            "context7"
            "grep_app"
            "ingar"
          ];
        };
        explorer = {
          model = "amazon-bedrock/us.anthropic.claude-haiku-4-5-20251001-v1:0";
          skills = [ ];
          mcps = [ ];
        };
        designer = {
          model = "amazon-bedrock/us.anthropic.claude-sonnet-4-6";
          variant = "medium";
          skills = [ ];
          mcps = [ ];
        };
        fixer = {
          model = "amazon-bedrock/us.anthropic.claude-haiku-4-5-20251001-v1:0";
          skills = [ ];
          mcps = [ ];
        };
      };
    };
  };
in
{
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
