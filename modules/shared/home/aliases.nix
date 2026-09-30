# Operator shell aliases consumed by both fish and zsh modules.
#
# Pure helper (not a NixOS/HM module) — exports the alias attrset so fish.nix
# and zsh.nix can each set `programs.<shell>.shellAliases` from the same
# source.
_: {
  ss = "screensaver.sh";
}
