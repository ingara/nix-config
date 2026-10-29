{ pkgs }:
let
  resolver = pkgs.writeShellApplication {
    name = "herdr-workspace-repos";
    runtimeInputs = [
      pkgs.git
      pkgs.jq
    ];
    text = builtins.readFile ./herdr-workspace-repos.sh;
  };
in
pkgs.runCommand "herdr-workspace-repos-tested"
  {
    nativeBuildInputs = [
      pkgs.git
      pkgs.jq
    ];
    meta.mainProgram = "herdr-workspace-repos";
  }
  ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    ${pkgs.bashNonInteractive}/bin/bash ${./herdr-workspace-repos-test.sh} \
      ${resolver}/bin/herdr-workspace-repos ${./herdr-workspace-repos-fixture.sh}
    mkdir -p "$out/bin"
    ln -s ${resolver}/bin/herdr-workspace-repos "$out/bin/herdr-workspace-repos"
  ''
