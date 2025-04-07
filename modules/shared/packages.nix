{ pkgs, ... }:

with pkgs; [
  eza
  colima
  docker
  fd
  htop
  nixpkgs-fmt
  curlie
  ngrok
  miniserve
  pre-commit
  wireguard-tools
  git-absorb
  k6
  nerd-font-patcher
  fastfetch
  neofetch
  nerdfetch
  tealdeer
  nixd
  yq-go
  jq
  chafa
  glow
  magic-wormhole

  # Better userland for macOS
  coreutils
  findutils
  gnugrep
  gnused
  lazygit
  wget

  # node stuff
  nodejs_20
  corepack_20
  nodePackages.vercel

  rustc
  cargo

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

