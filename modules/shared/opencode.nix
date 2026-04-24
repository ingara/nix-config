# OpenCode permission config
#
# Uses the upstream `programs.opencode` home-manager module (writes
# $XDG_CONFIG_HOME/opencode/opencode.json from `settings`, auto-adds
# "$schema"). Single nix source of truth — selects between two profiles
# based on `myOptions.opencode.hostClass`:
#
#   workstation (default) — laptop / interactive use
#   server                — non-interactive servers (lumar, mythos)
#                           Adds outbound network/exec denies (ssh/scp/rsync/nc),
#                           shutdown/reboot denies, and read-only systemctl/docker
#                           inspection allowlists on top of the workstation profile.
#
# Both profiles share the same base: ask-by-default for bash, narrow allowlist
# for safe inspection commands, hard denies for irreversible actions.
#
# Background and rationale: bash is the universal escape hatch in opencode
# (issue anomalyco/opencode#22375), so the only meaningful hardening axis is
# `permission.bash`. See also the Alexey Grigorev `terraform destroy` incident
# for why some patterns are `deny` rather than `ask`.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.myOptions.opencode) hostClass;

  # ---------------------------------------------------------------------------
  # Base profile (workstation)
  # ---------------------------------------------------------------------------
  baseSettings = {
    # MCP servers — same set on every host. Additional servers (typically
    # private/internal endpoints) can be added by other modules via
    # `programs.opencode.settings.mcp.<name> = { ... }` and will merge
    # into this attrset.
    #
    # Tools surface in opencode's catalog as `<server>_<tool>` (run /mcp
    # in opencode to see exact names). For aggregator MCP servers (e.g.
    # MCPJungle), the upstream tool naming convention `<source>__<tool>`
    # is preserved and prefixed with the opencode server name.
    mcp = {
      # Context7 — library-docs lookup for code-aware questions.
      # https://github.com/upstash/context7
      context7 = {
        type = "remote";
        url = "https://mcp.context7.com/mcp";
      };
    };

    permission = {
      # Reads outside the workspace prompt for approval.
      external_directory = "ask";

      # File reads. Most are fine; secrets are denied even though `read`
      # defaults to allow.
      read = {
        "*" = "allow";
        "*.env" = "deny";
        "*.env.*" = "deny";
        "*.env.example" = "allow";
        "*.key" = "deny";
        "*.pem" = "deny";
        "id_rsa*" = "deny";
        "id_ed25519*" = "deny";
        "**/credentials*" = "deny";
        "**/secrets/*" = "deny";
        "~/.ssh/**" = "deny";
        "~/.aws/**" = "deny";
        "~/.config/op/**" = "deny";
        "~/.config/sops/**" = "deny";
        "~/.config/gh/**" = "deny";
        "~/.config/1Password/**" = "deny";
      };

      # Bash is the universal escape hatch — the most important section.
      # Order: catch-all "ask" first; allowlist for inspection; denylist for
      # irreversible actions. Last matching rule wins.
      bash = {
        "*" = "ask";

        # --- Filesystem inspection ---
        "ls" = "allow";
        "ls *" = "allow";
        "pwd" = "allow";
        "stat *" = "allow";
        "file *" = "allow";
        "tree" = "allow";
        "tree *" = "allow";
        "wc *" = "allow";

        # --- Command lookup ---
        "which" = "allow";
        "which *" = "allow";
        "type *" = "allow";
        "command -v *" = "allow";

        # --- Process / system info ---
        "ps" = "allow";
        "ps *" = "allow";
        "free" = "allow";
        "free *" = "allow";
        "df" = "allow";
        "df *" = "allow";
        "du *" = "allow";
        "uptime" = "allow";
        "uname" = "allow";
        "uname *" = "allow";
        "hostname" = "allow";
        "id" = "allow";
        "whoami" = "allow";
        "date" = "allow";
        "date *" = "allow";

        # NOTE: `env` and `printenv` are deliberately NOT allowlisted. They
        # leak secret env vars (API keys, OP tokens, GH tokens) into the
        # model context. Force them through `ask`.

        # --- Search / data tools ---
        "rg" = "allow";
        "rg *" = "allow";
        "fd" = "allow";
        "fd *" = "allow";
        "jq *" = "allow";
        "yq *" = "allow";

        # --- Git (read-only) ---
        "git status" = "allow";
        "git status *" = "allow";
        "git diff" = "allow";
        "git diff *" = "allow";
        "git log" = "allow";
        "git log *" = "allow";
        "git show" = "allow";
        "git show *" = "allow";
        "git branch" = "allow";
        "git branch *" = "allow";
        "git remote" = "allow";
        "git remote *" = "allow";
        "git stash list" = "allow";
        "git stash list *" = "allow";
        "git stash show *" = "allow";
        "git rev-parse *" = "allow";
        "git ls-files" = "allow";
        "git ls-files *" = "allow";
        "git ls-remote *" = "allow";
        "git config --get *" = "allow";
        "git config --get-all *" = "allow";
        "git config --list" = "allow";
        "git config --list *" = "allow";
        "git blame *" = "allow";
        "git describe" = "allow";
        "git describe *" = "allow";
        "git tag" = "allow";
        "git tag --list" = "allow";
        "git tag -l*" = "allow";
        "git worktree list" = "allow";
        "git worktree list *" = "allow";
        "git reflog" = "allow";
        "git reflog *" = "allow";
        "git cat-file *" = "allow";

        # --- just (read-only / safe) ---
        # Specific recipes that don't mutate. Deploys, switches, publishes
        # fall through to `*: ask`.
        "just" = "allow";
        "just --list" = "allow";
        "just --list *" = "allow";
        "just --summary" = "allow";
        "just --evaluate" = "allow";
        "just --show *" = "allow";
        "just fmt-check" = "allow";
        "just lint" = "allow";

        # --- nix (read-only) ---
        "nix flake show" = "allow";
        "nix flake show *" = "allow";
        "nix flake metadata" = "allow";
        "nix flake metadata *" = "allow";
        "nix flake check" = "allow";
        "nix flake check *" = "allow";
        "nix-info" = "allow";
        "nix-info *" = "allow";
        "nix eval *" = "allow";
        "nix store path-info *" = "allow";
        "nix derivation show *" = "allow";
        "nix search *" = "allow";
        "nix why-depends *" = "allow";
        "nixpkgs-fmt --check *" = "allow";

        # --- tailscale (read-only) ---
        "tailscale status" = "allow";
        "tailscale status *" = "allow";
        "tailscale ping *" = "allow";
        "tailscale dns status" = "allow";

        # --- npm registry (read-only metadata) ---
        # `npm view <pkg>` queries the registry without installing.
        # Useful for version / integrity / dependency lookups.
        "npm view *" = "allow";

        # --- gh (read-only) ---
        # `gh api` is denied below — too easy to mutate state via -X DELETE
        # / -f params (auto-promotes to POST). `gh auth` mutates token state.
        "gh pr view" = "allow";
        "gh pr view *" = "allow";
        "gh pr list" = "allow";
        "gh pr list *" = "allow";
        "gh pr diff *" = "allow";
        "gh pr checks *" = "allow";
        "gh issue view *" = "allow";
        "gh issue list" = "allow";
        "gh issue list *" = "allow";
        "gh repo view" = "allow";
        "gh repo view *" = "allow";

        # --- Hard denies ---
        # These bypass `ask` and fail outright. Force the user into a separate
        # terminal where they can think before acting.

        # rm -rf (destroying root / home)
        "rm -rf /" = "deny";
        "rm -rf /*" = "deny";
        "rm -rf ~" = "deny";
        "rm -rf ~/*" = "deny";
        "rm -rf ." = "deny";
        "rm -rf .." = "deny";
        "rm -rf $HOME" = "deny";
        "rm -rf $HOME/*" = "deny";

        # Privilege escalation
        "sudo" = "deny";
        "sudo *" = "deny";
        "su" = "deny";
        "su *" = "deny";

        # Filesystem corruption
        "dd *" = "deny";
        "mkfs*" = "deny";
        "chown *" = "deny";

        # Git destructive
        "git push --force*" = "deny";
        "git push -f" = "deny";
        "git push -f *" = "deny";
        "git push --force-with-lease*" = "deny";
        "git reset --hard*" = "deny";
        "git clean *" = "deny";
        "git branch -D *" = "deny";
        "git branch --delete --force*" = "deny";

        # GitHub API mutation
        "gh api *" = "deny";
        "gh auth *" = "deny";
        "gh secret *" = "deny";
        "gh repo delete*" = "deny";
        "gh release delete*" = "deny";

        # Nix destructive (route through `just update`, etc.)
        "nix flake update*" = "deny";
        "nix-collect-garbage*" = "deny";
        "nix store delete*" = "deny";
      };
    };
  };

  # ---------------------------------------------------------------------------
  # Server profile additions (merged on top of base via lib.recursiveUpdate)
  # ---------------------------------------------------------------------------
  serverExtras = {
    permission = {
      read = {
        # SOPS-deployed secret materialisation paths
        "/run/secrets/**" = "deny";
        "/var/lib/sops-nix/**" = "deny";
      };

      bash = {
        # --- Read-only service / container inspection ---
        "systemctl status*" = "allow";
        "systemctl is-active *" = "allow";
        "systemctl is-enabled *" = "allow";
        "systemctl is-failed *" = "allow";
        "systemctl list-units*" = "allow";
        "systemctl list-unit-files*" = "allow";
        "systemctl cat *" = "allow";
        "systemctl show *" = "allow";
        "docker ps" = "allow";
        "docker ps *" = "allow";
        "docker inspect *" = "allow";
        "docker stats*" = "allow";
        "docker images" = "allow";
        "docker images *" = "allow";

        # --- Outbound network / exec ---
        # Servers should not initiate SSH or arbitrary network connections.
        "ssh" = "deny";
        "ssh *" = "deny";
        "scp" = "deny";
        "scp *" = "deny";
        "rsync" = "deny";
        "rsync *" = "deny";
        "nc" = "deny";
        "nc *" = "deny";
        "ncat" = "deny";
        "ncat *" = "deny";
        "socat" = "deny";
        "socat *" = "deny";

        # --- Service / host lifecycle ---
        "shutdown*" = "deny";
        "reboot*" = "deny";
        "poweroff*" = "deny";
        "halt*" = "deny";
        "systemctl poweroff*" = "deny";
        "systemctl reboot*" = "deny";
        "systemctl halt*" = "deny";
        "systemctl stop docker*" = "deny";
        "systemctl disable *" = "deny";
        "systemctl mask *" = "deny";
        "docker system prune*" = "deny";
        "docker rm -f*" = "deny";
        "docker stop *" = "ask";
        "docker volume rm*" = "deny";
      };
    };
  };

  finalSettings =
    if hostClass == "server" then lib.recursiveUpdate baseSettings serverExtras else baseSettings;
in
{
  programs.opencode = {
    enable = true;
    package = pkgs.opencode;
    settings = finalSettings;
  };
}
