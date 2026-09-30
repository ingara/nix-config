# worktrunk — `wt` Git worktree manager for parallel agent workflows.
#
# No upstream HM module, so the package + shell integration are wired by
# hand. The integration is a wrapper function emitted by
# `wt config shell init <shell>`; without it `wt switch` can only print the
# target dir, not `cd` the parent shell into it. We source it at interactive
# startup (same idiom as zoxide/starship) rather than letting
# `wt config shell install` mutate shell config imperatively.
{ pkgs, ... }:

let
  fishInit = ''
    wt config shell init fish | source
  '';
  zshInit = ''
    eval "$(wt config shell init zsh)"
  '';
in
{
  home.packages = [ pkgs.worktrunk ];

  programs.fish.interactiveShellInit = fishInit;

  programs.zsh.initContent = zshInit;

  myOptions.developerEnvironmentParity = {
    packages.worktrunk = {
      package = pkgs.worktrunk;
      commands = [ "wt" ];
    };
    surfaces.cliWorktrunk = {
      inherit fishInit zshInit;
    };
  };
}
