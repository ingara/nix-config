# Shared nixpkgs config + overlays.
#
# Imported in both system and home-manager contexts so HM gets the same
# overlays as the host system after we drop `useGlobalPkgs = true`.
# Overlays themselves are platform-gated internally (see public/overlays/*).
_:

{
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
