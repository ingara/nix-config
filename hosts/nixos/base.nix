{
  config,
  lib,
  pkgs,
  userConfig,
  ...
}:

let
  user = userConfig.username;
in
{
  imports = [
    ../../modules/shared
    ../../modules/nixos
  ];

  # Set your time zone
  time.timeZone = "Europe/Oslo";

  networking = {
    useDHCP = lib.mkForce true;
  };

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

  environment.systemPackages = with pkgs; [
    gitFull
    neovim
  ];

  system.stateVersion = "23.11"; # Don't change this
}
