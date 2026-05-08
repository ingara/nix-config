# Shared shell aliases consumed by both fish and zsh modules.
#
# Pure helper (not a NixOS/HM module) — exports the alias attrset so fish.nix
# and zsh.nix can each set `programs.<shell>.shellAliases` from the same
# source.
_: {
  cat = "bat";
  g = "git";
  tls = "tmux-lazy-session";
  tf = "terraform";
  lg = "lazygit";
  kubectl = "kubecolor";
  br = "broot";
  vim = "nvim";
  top = "btm"; # Use bottom instead of top

  # Eza stuff
  ls = "eza";
  l = "eza -l --all --group-directories-first --git";
  ll = "eza -l --all --all --group-directories-first --git";
  lt = "eza -T --git-ignore --level=2 --group-directories-first";
  llt = "eza -lT --git-ignore --level=2 --group-directories-first";
  lT = "eza -T --git-ignore --level=4 --group-directories-first";

  cdg = "cd $(git rev-parse --show-toplevel)";
  zj = "zellij -l welcome";

  c = "claude";
  oc = "opencode";
}
