{ lib, ... }:
{
  options.myOptions = {
    user = {
      username = lib.mkOption {
        type = lib.types.str;
        default = "user";
      };
      fullName = lib.mkOption {
        type = lib.types.str;
        default = "Nix User";
      };
      email = lib.mkOption {
        type = lib.types.str;
        default = "user@example.com";
      };
      signingKey = lib.mkOption {
        type = lib.types.str;
        default = "SIGNING_KEY_PLACEHOLDER";
      };
    };
    hasGui = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    mutableDotfiles = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    zellijAutoAttach = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    sshSignProgram = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    gitCredentialHelper = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
  };
}
