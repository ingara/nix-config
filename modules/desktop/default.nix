{ pkgs, ... }:
{
  home.packages = with pkgs; [
    firefox
    rofi
    xclip
  ];
}
