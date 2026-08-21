{
  config,
  lib,
  pkgs,
  ...
}:

{
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "1password-gui"
      "1password"
    ];

  security.polkit.enable = true;

  programs._1password.enable = true;

  # Linux only; macOS installs the GUI via Homebrew.
  programs._1password-gui = lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && config.myOptions.hasGui) {
    enable = true;
    polkitPolicyOwners = [ config.myOptions.user.username ];
  };

  # Autostart the GUI (tray + SSH agent) with the graphical session. Upstream
  # has no autostart option, and its "start at login" setting writes an XDG
  # autostart entry nothing consumes under UWSM — so bind a user service to
  # graphical-session.target instead. --silent starts to the tray only.
  systemd.user.services."1password" =
    lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && config.myOptions.hasGui)
      {
        description = "1Password GUI";
        wantedBy = [ "graphical-session.target" ];
        partOf = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        serviceConfig.ExecStart = "${config.programs._1password-gui.package}/bin/1password --silent";
      };
}
