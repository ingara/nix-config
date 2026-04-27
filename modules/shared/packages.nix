{ pkgs, ... }:

with pkgs;
[
  awscli2
  chafa
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
  nh
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
  wget
  xh

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

  # Zellij session display for zjstatus (SSH-aware)
  (pkgs.writeShellScriptBin "zellij-session-display.sh" (
    builtins.readFile ../../dotfiles/scripts/zellij-session-display.sh
  ))
]
