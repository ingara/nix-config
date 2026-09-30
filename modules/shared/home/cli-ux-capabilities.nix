{ pkgs }:

let
  packages = {
    inherit (pkgs) bat;
    inherit (pkgs) bottom;
    inherit (pkgs) broot;
    inherit (pkgs) eza;
    inherit (pkgs) fish;
    inherit (pkgs) fzf;
    git = pkgs.gitFull;
    inherit (pkgs) starship;
    inherit (pkgs) zoxide;
  };
in
{
  inherit packages;

  aliases = {
    cat = "bat";
    g = "git";
    cdg = "cd $(git rev-parse --show-toplevel)";
    br = "broot";
    top = "btm";
    vim = "nvim";
    lg = "lazygit";
    ls = "eza";
    l = "eza -l --all --group-directories-first --git";
    ll = "eza -l --all --all --group-directories-first --git";
    lt = "eza -T --git-ignore --level=2 --group-directories-first";
    llt = "eza -lT --git-ignore --level=2 --group-directories-first";
    lT = "eza -T --git-ignore --level=4 --group-directories-first";
  };

  # Broot has a Home Manager module, but enabling it also generates config and
  # shell integration that this shared bundle does not own.
  rawPackages = [
    packages.broot
  ];
}
