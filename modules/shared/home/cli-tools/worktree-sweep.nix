{ pkgs, ... }:

let
  python = pkgs.python3.withPackages (ps: [
    ps.prompt-toolkit
    ps.questionary
    ps.rich
  ]);

  worktreeSweep = pkgs.writeShellApplication {
    name = "worktree-sweep";
    runtimeInputs = [
      pkgs.git
      pkgs.lsof
    ];
    text = ''
      exec ${python}/bin/python3 ${./worktree-sweep.py} "$@"
    '';
  };
in
{
  home.packages = [ worktreeSweep ];
}
