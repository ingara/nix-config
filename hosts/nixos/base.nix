{
  config,
  pkgs,
  ...
}:

let
  user = config.myOptions.user.username;
in
{
  imports = [
    ../../modules/shared/system
    ../../modules/nixos
  ];

  # Set your time zone
  time.timeZone = "Europe/Oslo";

  # Turn on flag for proprietary software
  nix = {
    nixPath = [ "nixos-config=/home/${user}/.local/share/src/nixos-config:/etc/nixos" ];
    settings.allowed-users = [ "${user}" ];
    package = pkgs.nixVersions.latest;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  # Programs
  programs = {
    gnupg.agent.enable = true;
    fish.enable = true;
  };

  # User
  users.users = {
    ${user} = {
      isNormalUser = true;
      extraGroups = [
        "wheel" # Enable 'sudo' for the user.
      ];
      shell = pkgs.fish;
    };
  };

  # Don't require password for users in `wheel` group for these commands
  security.sudo = {
    enable = true;
    extraRules = [
      {
        commands = [
          {
            command = "${pkgs.systemd}/bin/reboot";
            options = [ "NOPASSWD" ];
          }
        ];
        groups = [ "wheel" ];
      }
    ];
  };

  # Tailscale mesh VPN — access services across machines privately
  services.tailscale = {
    enable = true;
    extraSetFlags = [ "--ssh" ];
  };

  # Don't restart tailscaled during nixos-rebuild switch / deploy-rs
  # activation. Restarting it tears down the tunnel that the deploy SSH
  # is using; deploy-rs's magic-rollback then sees the dropped session
  # as a failed activation and rolls the system back, even though the
  # switch itself succeeded. Tailscale picks up the new binary on the
  # next reboot or on a manual `systemctl restart tailscaled` from a
  # session that isn't tunneled through it (root SSH over the same
  # tunnel will also drop — use the cloud console for an explicit
  # restart, or just wait for the next reboot).
  systemd.services.tailscaled.restartIfChanged = false;

  environment.systemPackages = with pkgs; [
    gitFull
    graphite-cli
    neovim
  ];

}
