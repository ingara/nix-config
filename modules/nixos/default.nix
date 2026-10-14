{
  pkgs,
  ...
}:

{
  imports = [
    ./1password.nix
    ./nixos-version.nix
  ];

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    openssl
    zlib
    stdenv.cc.cc.lib
  ];
}
