{
  config,
  lib,
  pkgs,
  userConfig,
  ...
}:

{
  imports = [
    ../base.nix
    ../../../modules/nixos/disko-config.nix
  ];

  networking.hostName = "vboxnixos";

  # Use the systemd-boot EFI boot loader
  boot = {
    loader = {
      grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true;
      };
    };
    initrd.availableKernelModules = [
      "ata_piix"
      "ohci_pci"
      "ehci_pci"
      "ahci"
      "sd_mod"
      "sr_mod"
    ];
  };

  # GNOME desktop environment
  services = {
    # Better support for general peripherals
    libinput.enable = true;

    xserver = {
      enable = true;

      videoDrivers = lib.mkForce [
        "vmware"
        "virtualbox"
        "modesetting"
      ];

      # Turn Caps Lock into Ctrl
      xkb = {
        layout = "us";
        options = "ctrl:nocaps";
      };
    };

    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;

    gvfs.enable = true; # Mount, trash, and other functionalities
    tumbler.enable = true; # Thumbnail support for images
  };

  # Exclude unwanted GNOME packages
  environment.gnome.excludePackages = (
    with pkgs;
    [
      gnome-photos
      gnome-tour
      cheese
      gnome-music
      epiphany
      geary
      evince
      gnome-characters
      totem
      tali
      iagno
      hitori
      atomix
    ]
  );

  # VirtualBox guest services
  systemd.user.services =
    let
      vbox-client = desc: flags: {
        description = "VirtualBox Guest: ${desc}";
        wantedBy = [ "graphical-session.target" ];
        requires = [ "dev-vboxguest.device" ];
        after = [ "dev-vboxguest.device" ];

        unitConfig.ConditionVirtualization = "oracle";
        serviceConfig.ExecStart = "${config.boot.kernelPackages.virtualboxGuestAdditions}/bin/VBoxClient -fv ${flags}";
      };
    in
    {
      virtualbox-resize = vbox-client "Resize" "--vmsvga";
      virtualbox-clipboard = vbox-client "Clipboard" "--clipboard";
    };

  virtualisation = {
    virtualbox.guest = {
      enable = true;
    };
  };

  # VirtualBox specific packages
  environment.systemPackages = with pkgs; [
    inetutils
  ];
}
