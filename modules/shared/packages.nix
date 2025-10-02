{ pkgs, ... }:

with pkgs;
[
  chafa
  colima
  curlie
  docker
  eza
  fastfetch
  fd
  git-absorb
  glow
  htop
  just
  jq
  k6
  magic-wormhole
  miniserve
  neofetch
  neovim
  nerd-font-patcher
  nerdfetch
  ngrok
  nh
  nixd
  nixfmt-rfc-style
  pre-commit
  statix
  ripgrep
  rustup
  tealdeer
  wireguard-tools
  yq-go
  zellij

  # Better userland for macOS
  coreutils
  findutils
  gnugrep
  gnused
  lazygit
  wget

  # node stuff
  nodejs_22
  corepack_22
  nodePackages.vercel

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
]
