_:

{
  environment = {
    variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      XDG_CONFIG_HOME = "$HOME/.config";
      # Since Claude Code doesn't respect XDG_CONFIG_HOME
      CLAUDE_CONFIG_DIR = "$HOME/.config/claude";
    };
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
