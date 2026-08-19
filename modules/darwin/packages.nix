{ pkgs }:

# Darwin-only additions to home.packages. `shared/packages.nix` is NOT
# imported here: it already reaches this host via `environment.systemPackages`
# in `public/hosts/darwin/default.nix`, so pulling it in again here would
# double-feed the whole shared list (once at system scope, once at user
# scope).
with pkgs;
[
  # colima is provided declaratively via the home-manager `services.colima`
  # module (see ./colima.nix), so it's not listed here.
  docker
  terminal-notifier

  # Better userland for macOS
  coreutils
  findutils
  gnugrep
  gnused

  dockutil
  pkgs.nerd-fonts.hack
  pkgs.nerd-fonts.caskaydia-cove
  pkgs.nerd-fonts.zed-mono
  pkgs.nerd-fonts.victor-mono
  # The monospace font (Pragmasevka) is installed by Stylix's font-packages
  # target from `stylix.fonts.monospace` (shared/home/stylix-base.nix).
  pkgs.sketchybar-app-font
]
