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
        default = "";
      };
    };
    dotfiles = {
      repoRoot = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Root path of the nix-config repo, used for dotfile symlinks";
      };
    };
    opencode = {
      hostClass = lib.mkOption {
        type = lib.types.enum [
          "workstation"
          "server"
        ];
        default = "workstation";
        description = ''
          Selects which opencode permission profile is symlinked to
          ~/.config/opencode/opencode.json. "server" adds outbound
          network/exec denies (ssh/scp/rsync/nc) and shutdown/reboot denies
          on top of the workstation profile.
        '';
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
