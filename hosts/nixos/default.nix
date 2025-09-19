{
  config,
  inputs,
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
    ../../modules/nixos/disko-config.nix
  ];

  # Use the systemd-boot EFI boot loader.
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

  # Set your time zone.
  time.timeZone = "Europe/Oslo";

  networking = {
    hostName = "vboxnixos";
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

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Manages keys and such
  programs = {
    gnupg.agent.enable = true;

    # Needed for anything GTK related
    # dconf.enable = true;

    fish.enable = true;
  };

  environment.gnome.excludePackages = with pkgs; [
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
  ];
  services = {
    # displayManager.defaultSession = "none+bspwm";

    # Better support for general peripherals
    libinput.enable = true;
    xserver = {
      enable = true;

      videoDrivers = lib.mkForce [
        "vmware"
        "virtualbox"
        "modesetting"
      ];

      displayManager.gdm.enable = true;
      desktopManager.gnome.enable = true;

      # Turn Caps Lock into Ctrl
      xkb = {
        layout = "us";
        options = "ctrl:nocaps";
      };
    };

    # openssh.enable = true;

    gvfs.enable = true; # Mount, trash, and other functionalities
    tumbler.enable = true; # Thumbnail support for images
  };

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

  # Enable sound
  # sound.enable = true;
  # hardware = {
  #   pulseaudio.enable = true;
  #
  #   # Video support
  #   opengl = {
  #     enable = true;
  #     driSupport32Bit = true;
  #     driSupport = true;
  #   };
  #
  #   nvidia.modesetting.enable = true;
  # };

  # Sync state between machines
  # Add docker daemon
  virtualisation = {
    #   docker = {
    #     enable = true;
    #     logDriver = "json-file";
    #   };
    virtualbox.guest = {
      enable = true;
    };
  };

  # User
  users.users = {
    ${user} = {
      isNormalUser = true;
      extraGroups = [
        "wheel" # Enable ‘sudo’ for the user.
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

  fonts.packages = with pkgs; [
    jetbrains-mono
    font-awesome
    noto-fonts
    noto-fonts-emoji
    # nerdfonts
  ];

  environment.systemPackages = with pkgs; [
    gitAndTools.gitFull
    inetutils
    neovim
  ];

  system.stateVersion = "23.11"; # Don't change this
}
