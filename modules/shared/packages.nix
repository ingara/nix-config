{ pkgs, ... }:

with pkgs;
[
  awscli2
  chafa
  dix
  dust
  eza
  fastfetch
  fd
  git-absorb
  gh-dash
  glow
  graphite-cli
  go
  broot
  bottom
  just
  kubecolor
  jq
  k6
  magic-wormhole
  miniserve
  neovim
  nerd-font-patcher
  nerdfetch
  ngrok
  nixd
  nixfmt
  osc
  statix
  ripgrep
  rustup
  tealdeer
  wireguard-tools
  yq-go
  zellij

  lazygit
  uv
  wget
  xh

  # terminal eye candy
  cbonsai
  lavat

  python3

  # node stuff
  nodejs_22
  corepack_22

  # fonts
  maple-mono.NF

  (buildGoModule rec {
    pname = "updo";
    version = "0.1.1";

    src = fetchFromGitHub {
      owner = "Owloops";
      repo = "updo";
      rev = "v${version}";
      hash = "sha256-sZfCtN7f80Qla6qzrl2iQ7V+lJeaDYA0DAAbiVXuxRQ=";
    };

    vendorHash = "sha256-lkNvVAtq4CxQQ8Buw+waWbId0XdLRnN/w6pE6C8fEgA=";
  })

  # Zellij URL picker script
  (pkgs.writeShellScriptBin "zellij-url-picker.sh" (
    builtins.readFile ../../dotfiles/scripts/zellij-url-picker.sh
  ))

  # Terminal screensaver selector
  (pkgs.writeShellScriptBin "screensaver.sh" (
    builtins.readFile ../../dotfiles/scripts/screensaver.sh
  ))

  # Zellij session display for zjstatus (SSH-aware)
  (pkgs.writeShellScriptBin "zellij-session-display.sh" (
    builtins.readFile ../../dotfiles/scripts/zellij-session-display.sh
  ))

  # tmux status-bar helpers (consumed by public/modules/shared/home/tmux.nix).
  # Names lack `.sh` so the tmux #(…) format strings stay tidy.
  (pkgs.writeShellScriptBin "tmux-cwd-icon" (
    builtins.readFile ../../dotfiles/scripts/tmux-cwd-icon.sh
  ))
  (pkgs.writeShellScriptBin "tmux-git-status" (
    builtins.readFile ../../dotfiles/scripts/tmux-git-status.sh
  ))
  (pkgs.writeShellScriptBin "tmux-keys-popup" (
    builtins.readFile ../../dotfiles/scripts/tmux-keys-popup.sh
  ))
]
