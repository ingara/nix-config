{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.lavish-axi;
in
{
  options.programs.lavish-axi = {
    enable = lib.mkEnableOption "Lavish HTML artifact review";
    package = lib.mkPackageOption pkgs "lavish-axi" { };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
  };
}
