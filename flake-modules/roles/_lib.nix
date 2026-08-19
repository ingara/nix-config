# mkRole — assemble an easy-hosts module bundle from nixos-system modules and
# home-manager modules. No darwin slot: graphical/gaming/nvidia are nixos-only
# tags (design rationale: a tag applies to any host of its class, and a bundle
# of linux modules would fail eval on darwin — class-specific system config goes
# through perClass.<class>, never a tag).
#
# HM modules are injected via `home-manager.sharedModules` so they reach the
# host's declared user without naming the username here (the same mechanism the
# private perClass uses for the universal HM base).
#
# This file is intentionally NOT a flake-parts module: import-tree's filter
# (`andNot (hasInfix "/_") (hasSuffix ".nix")`, verified against the locked rev)
# drops any path containing "/_", so `roles/_lib.nix` is excluded from
# auto-import. Sibling role files `import ./_lib.nix` directly.
#
#   mkRole { system = [ ./foo.nix ]; home = [ ./bar.nix ]; }
#   => { modules = [ ./foo.nix { home-manager.sharedModules = [ ./bar.nix ]; } ]; }
{
  system ? [ ],
  home ? [ ],
}:
{
  modules = system ++ (if home == [ ] then [ ] else [ { home-manager.sharedModules = home; } ]);
}
