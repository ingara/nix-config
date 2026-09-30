{ config, ... }:

{
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
  };
  myOptions.developerEnvironmentParity.surfaces.cliUx.fzf = {
    inherit (config.programs.fzf)
      enable
      enableBashIntegration
      enableFishIntegration
      enableZshIntegration
      ;
  };
}
