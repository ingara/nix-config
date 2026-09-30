# direnv with nix-direnv backend so `.envrc` files auto-load flake /
# shell-nix environments on `cd`.
{ config, ... }:

{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    # Suppress the noisy `export +VAR +VAR …` env-diff dump on every load;
    # keep the loading / cached-shell status lines.
    config.global.hide_env_diff = true;
  };

  myOptions.developerEnvironmentParity = {
    packages = {
      direnv = {
        package = config.programs.direnv.package;
        commands = [ "direnv" ];
      };
    };
    surfaces.cliDirenv = {
      inherit (config.programs.direnv)
        enable
        enableBashIntegration
        enableFishIntegration
        enableNushellIntegration
        enableZshIntegration
        silent
        ;
      nixDirenv = {
        enable = config.programs.direnv.nix-direnv.enable;
        provider = {
          name = config.programs.direnv.nix-direnv.package.name;
          storePath = toString config.programs.direnv.nix-direnv.package;
        };
      };
      inherit (config.programs.direnv) config;
    };
  };
}
