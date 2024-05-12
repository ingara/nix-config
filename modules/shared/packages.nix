{ pkgs, ... }:

with pkgs; [
  eza
  colima
  docker
  fd
  htop
  nixpkgs-fmt
  ripgrep
  # magic-wormhole
  # azure-cli # done via brew
  # qmk # not working on aarch64-darwin
  ngrok
  miniserve
  pre-commit
  wireguard-tools
  # act # https://github.com/nektos/act
  git-absorb
  k6
  nerd-font-patcher

  ##TF
  # terraform
  # tfenv # installed with brew
  tflint
  terragrunt

  # Nix language server https://github.com/oxalica/nil
  # nil
  nixd

  # k8s stuff
  kubectl
  kubecolor
  kubectx
  yq-go

  # Better userland for macOS
  coreutils
  findutils
  gnugrep
  gnused
  lazygit

  # node stuff
  nodejs_20
  corepack_20
  nodePackages.vercel
  # nodePackages_latest.pnpm

  rustc
  cargo

  nixd

  # yabai
  # skhd

  (buildGoModule {
   name = "terraform-config-inspect";
   version = "latest";

   src = fetchFromGitHub {
   owner = "hashicorp";
   repo = "terraform-config-inspect";
   rev = "a34142ec2a72dd916592afd3247dd354f1cc7e5c";
   hash = "sha256-+NsVQ3K7fiQjI/41kPV3iAzFO3Z3Z4oeUA5gJgR+EyU=";
   };

   vendorHash = "sha256-JO02/PrlyFpQnNAb0ZZ8sfGiMmGjtbhwmAasWkHPg1A=";
   })

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

