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

  time.timeZone = "Europe/Oslo";

  nix = {
    nixPath = [ "nixos-config=/home/${user}/.local/share/src/nixos-config:/etc/nixos" ];
    settings.allowed-users = [ "${user}" ];
    package = pkgs.nixVersions.latest;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  programs = {
    gnupg.agent.enable = true;
    fish.enable = true;
  };

  users.users = {
    ${user} = {
      isNormalUser = true;
      extraGroups = [
        "wheel" # Enable 'sudo' for the user.
      ];
      shell = pkgs.fish;
    };
  };

  security.sudo = {
    enable = true;
    extraRules = [
      {
        commands = [
          {
            # Symlink path, not a store-path pin: sudo matches the literal
            # PATH-resolved path without canonicalizing symlinks, so
            # `${pkgs.systemd}/bin/reboot` never matches `sudo reboot` (which
            # resolves to this symlink) and falls through to a password
            # prompt — and the store path goes stale on every systemd bump.
            # Root-owned and part of the activated system, so no looser in
            # practice. Same rationale as the workstation nixos-rebuild rule.
            command = "/run/current-system/sw/bin/reboot";
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

  environment.systemPackages = with pkgs; [
    gitFull
    graphite-cli
    neovim
  ];

}
