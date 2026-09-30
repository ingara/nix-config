# mise — polyglot runtime version manager. Replaces asdf/nvm/pyenv.
{ config, ... }:

{
  programs.mise = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
    # corepack shims (pnpm/yarn) live inside each mise-installed node, so they
    # run on the project's pinned node instead of the system fallback.
    globalConfig.settings.node.corepack = true;
  };

  myOptions.developerEnvironmentParity = {
    packages.mise = {
      package = config.programs.mise.package;
      commands = [ "mise" ];
    };
    surfaces.cliMise = {
      inherit (config.programs.mise)
        enable
        enableBashIntegration
        enableFishIntegration
        enableMutableConfig
        enableNushellIntegration
        enableZshIntegration
        globalConfig
        ;
    };
  };
}
