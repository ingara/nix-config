{ config, ... }:

{
  programs.bat.enable = true;
  myOptions.developerEnvironmentParity.surfaces.cliUx.bat.enable = config.programs.bat.enable;
}
