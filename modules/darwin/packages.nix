{ pkgs }:

with pkgs;
let shared-packages = import ../shared/packages.nix { inherit pkgs; }; in
shared-packages ++ [
  dockutil
  (pkgs.nerdfonts.override {
    fonts = [
      "Hack"
      "CascadiaCode"
      "ZedMono"
      "VictorMono"
    ];
  })
]
