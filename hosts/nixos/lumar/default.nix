{
  modulesPath,
  lib,
  pkgs,
  userConfig,
  claude-code-nix,
  ...
}:

let
  user = userConfig.username;
  sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJOcn6jcqWIS4VF51EBurn28I/pJTPSfs3LgmCIV/ACF";
in
{
  imports = [
    ../base.nix
    ./disk-config.nix
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
  networking.useDHCP = false;
  system.stateVersion = "24.11";

  networking.hostName = "lumar";

  # Boot — UEFI with GRUB
  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
  };
  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_scsi"
    "sd_mod"
    "sr_mod"
  ];
  boot.initrd.kernelModules = [ "virtio_gpu" ];
  boot.kernelParams = [ "console=tty" ];

  # Networking — systemd-networkd with DHCP on enp1s0
  systemd.network.enable = true;
  systemd.network.networks."30-wan" = {
    matchConfig.Name = "enp1s0";
    networkConfig.DHCP = "ipv4";
  };

  # SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  users.users.${user}.openssh.authorizedKeys.keys = [ sshKey ];
  users.users.root.openssh.authorizedKeys.keys = [ sshKey ];

  # Fix ownership of signing key deployed via --extra-files (runs as root)
  system.activationScripts.signingKeyPermissions = ''
    if [ -f /home/${user}/.ssh/signing_key ]; then
      chown ${user}:users /home/${user}/.ssh/signing_key
      chmod 600 /home/${user}/.ssh/signing_key
      chown ${user}:users /home/${user}/.ssh
    fi
  '';

  environment.systemPackages = [
    claude-code-nix.packages.aarch64-linux.claude-code
    pkgs.meow
  ];
}
