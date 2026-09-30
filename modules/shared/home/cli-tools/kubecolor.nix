{
  config,
  lib,
  pkgs,
  ...
}:

{
  programs.kubecolor = {
    enable = true;
    enableAlias = true;
    enableZshIntegration = false;
  };
  stylix.targets.kubecolor.enable = true;

  home.packages = [ pkgs.kubectl ];

  myOptions.developerEnvironmentParity = {
    packages = {
      kubecolor = {
        package = config.programs.kubecolor.package;
        commands = [ "kubecolor" ];
      };
      kubectl = {
        package = pkgs.kubectl;
        commands = [ "kubectl" ];
      };
    };
    aliases.kubectl = lib.getExe config.programs.kubecolor.package;
    surfaces.cliKubecolor = {
      inherit (config.programs.kubecolor)
        enable
        enableAlias
        enableZshIntegration
        settings
        ;
      stylixTarget = config.stylix.targets.kubecolor.enable;
    };
  };
}
