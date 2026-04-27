_:

{
  imports = [ ./claude-code.nix ];

  environment = {
    variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      XDG_CONFIG_HOME = "$HOME/.config";
      # Since Claude Code doesn't respect XDG_CONFIG_HOME
      CLAUDE_CONFIG_DIR = "$HOME/.config/claude";
    };
  };

  # Cachix substituter for the claude-code-nix flake input. Without this,
  # `claude-code` is missing from cache.nixos.org (it's a custom flake, not
  # a nixpkgs package) and every deploy that bumps its version source-builds
  # the ~180MB native binary downloader. The Cachix is hourly-updated by the
  # claude-code-nix CI; see
  # https://github.com/sadjow/claude-code-nix#optional-enable-binary-cache-for-faster-installation
  #
  # Trade-off: trusts the substituter's signing key. Trust delta is small
  # since we already trust the flake input itself (which fetches binaries
  # from Anthropic with fixed hashes).
  nix.settings = {
    extra-substituters = [ "https://claude-code.cachix.org" ];
    extra-trusted-public-keys = [
      "claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk="
    ];
  };

  nixpkgs = {
    config = {
      allowUnfree = true;
      # allowBroken intentionally not set — let upstream "broken" markers
      # surface as eval errors so we can deal with them case-by-case
      # rather than silently shipping packages flagged broken.
      allowInsecure = false;
      allowUnsupportedSystem = true;
    };

    overlays =
      # Apply each overlay found in the /overlays directory
      let
        path = ../../overlays;
      in
      with builtins;
      map (n: import (path + ("/" + n))) (
        filter (n: match ".*\\.nix" n != null || pathExists (path + ("/" + n + "/default.nix"))) (
          attrNames (readDir path)
        )
      );
  };
}
