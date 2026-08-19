# direnv with nix-direnv backend so `.envrc` files auto-load flake /
# shell-nix environments on `cd`.
_: {
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    # Suppress the noisy `export +VAR +VAR …` env-diff dump on every load;
    # keep the loading / cached-shell status lines.
    config.global.hide_env_diff = true;
  };
}
