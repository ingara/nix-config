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
    theme = {
      scheme = lib.mkOption {
        type = lib.types.enum [
          "rose-pine"
          "rose-pine-moon"
          "rose-pine-dawn"
          "tokyo-night-dark"
          "tokyo-night-storm"
          "tokyo-night-moon"
          "tokyo-night-light"
          "kanagawa"
          "kanagawa-dragon"
          "catppuccin-macchiato"
          "catppuccin-mocha"
          "catppuccin-frappe"
          "catppuccin-latte"
        ];
        default = "rose-pine-moon";
        description = ''
          Active base16 color scheme. Drives Stylix across every themed
          surface (terminals, editors, status bars, GTK/Qt, KDE Plasma,
          cursors). Scheme names map 1:1 to YAML files in
          inputs.tinted-schemes/base16/<name>.yaml.
        '';
      };
      polarity = lib.mkOption {
        type = lib.types.enum [
          "light"
          "dark"
          "either"
        ];
        default = "dark";
        description = ''
          Forces light or dark variants where the target app supports
          both, or "either" to let Stylix pick.
        '';
      };
    };
  };
}
