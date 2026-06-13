# OpenAI Codex CLI — system-level wiring (darwin + nixos).
#
# Sibling to ./claude-code.nix. This module carries only the two host-level
# concerns; the per-user config.toml is deliberately NOT managed (see below):
#
#   1. CODEX_HOME → XDG. Codex defaults its entire state dir (config.toml,
#      credentials, history.jsonl, the SQLite session db) to ~/.codex and does
#      NOT honour XDG natively (openai/codex#1980). CODEX_HOME relocates the
#      whole root, so we point it at ~/.config/codex for parity with every
#      other tool. Fedora is HM-only (no system layer), so it sets CODEX_HOME
#      via home.sessionVariables instead — see hosts/fedora/default.nix.
#
#      config.toml itself is left unmanaged on purpose: Codex rewrites it at
#      runtime (model selection, per-project trust_level, onboarding/migration
#      flags, TUI theme — codex-rs/core/src/config/edit.rs), so a read-only
#      Nix store copy would break those writes. Same reason claude's
#      settings.json is unmanaged. Drop a hand-authored config.toml in place.
#
#   2. Cachix substituter for the codex-cli-nix flake input — same rationale
#      as claude-code's block: codex-cli-nix is a custom flake, not in
#      cache.nixos.org, so without this every version bump re-derives the
#      wrapped binary on the aarch64 servers. Hourly-updated by codex-cli-nix
#      CI. Trust delta is small — we already trust the flake input itself.
_:

{
  environment.variables.CODEX_HOME = "$HOME/.config/codex";

  nix.settings = {
    extra-substituters = [ "https://codex-cli.cachix.org" ];
    extra-trusted-public-keys = [
      "codex-cli.cachix.org-1:1Br3H1hHoRYG22n//cGKJOk3cQXgYobUel6O8DgSing="
    ];
  };
}
