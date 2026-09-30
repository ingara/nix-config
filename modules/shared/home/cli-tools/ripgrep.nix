{ config, pkgs, ... }:

let
  arguments = [
    "--column"
    "--line-number"
    "--max-columns-preview"
    "--colors=line:style:bold"
  ];
in
{
  programs.ripgrep = {
    enable = true;
    package = pkgs.ripgrep;
    inherit arguments;
  };

  myOptions.developerEnvironmentParity = {
    packages.ripgrep = {
      package = pkgs.ripgrep;
      commands = [ "rg" ];
    };
    surfaces.cliRipgrep = builtins.removeAttrs config.programs.ripgrep [ "package" ];
  };
}
