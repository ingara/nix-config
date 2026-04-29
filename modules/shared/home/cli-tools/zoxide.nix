# zoxide — `z <frecent-dir>` smart cd. `zi` fuzzy-picker lives in the
# shell initContent (see home/fish.nix and home/zsh.nix).
_: {
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
  };
}
