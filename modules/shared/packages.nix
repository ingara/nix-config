{ pkgs, ... }:

with pkgs;
[
  awscli2
  chafa
  dix
  dust
  fastfetch
  git-absorb
  glow
  graphite-cli
  k6
  magic-wormhole
  miniserve
  nerd-font-patcher
  nerdfetch
  ngrok
  rustup
  tealdeer
  wireguard-tools
  yq-go

  wget

  # terminal eye candy
  cbonsai
  lavat

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

  # Terminal screensaver selector
  (pkgs.writeShellScriptBin "screensaver.sh" (
    builtins.readFile ../../dotfiles/scripts/screensaver.sh
  ))

]
