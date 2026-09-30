# zoxide — `z <frecent-dir>` smart cd. `zi` fuzzy-picker lives in the
# shell initContent (see home/fish.nix and home/zsh.nix).
{ config, ... }:

{
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
  };
  myOptions.developerEnvironmentParity.surfaces.cliUx.zoxide = {
    inherit (config.programs.zoxide)
      enable
      enableBashIntegration
      enableFishIntegration
      enableNushellIntegration
      enableZshIntegration
      ;
  };
}
