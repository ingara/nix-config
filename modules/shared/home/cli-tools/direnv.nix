# direnv with nix-direnv backend so `.envrc` files auto-load flake /
# shell-nix environments on `cd`.
_: {
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
