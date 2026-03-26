{
  config,
  lib,
  pkgs,
  ...
}:

let
  user = config.myOptions.user.username;
in
{
  imports = [
    ../../modules/shared
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
    extraUpFlags = [ "--ssh" ];
  };

  environment.systemPackages = with pkgs; [
    gitFull
    graphite-cli
    neovim
  ];

}
