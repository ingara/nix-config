{ config, inputs, lib, pkgs, ... }:

let user = "ingar";
in
{
  imports = [
    ../../modules/shared
  ];

  # Use the systemd-boot EFI boot loader.
  # boot = {
  #   loader = {
  #     systemd-boot = {
  #       enable = true;
  #       configurationLimit = 42;
  #     };
  #     efi.canTouchEfiVariables = true;
  #   };
  #   initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" "v4l2loopback" ];
  #   kernelModules = [ "uinput" "v4l2loopback" ];
  #   extraModulePackages = [ pkgs.linuxPackages.v4l2loopback ];
  # };

  # Set your time zone.
  time.timeZone = "Europe/Oslo";

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  # networking = {
  #   hostName = "nixos"; # Define your hostname.
  #   useDHCP = false;
  #   interfaces.eno1.useDHCP = true;
  # };

  # Turn on flag for proprietary software
  nix = {
    nixPath = [ "nixos-config=/home/${user}/.local/share/src/nixos-config:/etc/nixos" ];
    settings.allowed-users = [ "${user}" ];
    package = pkgs.nixUnstable;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
   };

  # Manages keys and such
  programs = {
    gnupg.agent.enable = true;

    # Needed for anything GTK related
    # dconf.enable = true;

    fish.enable = true;
  };

  services = {
    xserver = {
      enable = true;

      videoDrivers = [ "nvidia" ];

      # This helps fix tearing of windows for Nvidia cards
      screenSection = ''
        Option       "metamodes" "nvidia-auto-select +0+0 {ForceFullCompositionPipeline=On}"
        Option       "AllowIndirectGLXProtocol" "off"
        Option       "TripleBuffer" "on"
      '';

      # LightDM Display Manager
      displayManager.defaultSession = "none+bspwm";
      displayManager.lightdm = {
        enable = true;
        greeters.slick.enable = true;
        # background = ../../modules/nixos/config/login-wallpaper.png;
      };

      # Tiling window manager
      windowManager.bspwm = {
        enable = true;
      };

      # Better support for general peripherals
      libinput.enable = true;

      # Turn Caps Lock into Ctrl
      xkb = {
        layout = "us";
        options = "ctrl:nocaps";
      };
    };

    # Picom, my window compositor with fancy effects
    #
    # Notes on writing exclude rules:
    #
    #   class_g looks up index 1 in WM_CLASS value for an application
    #   class_i looks up index 0
    #
    #   To find the value for a specific application, use `xprop` at the
    #   terminal and then click on a window of the application in question
    #
    picom = {
      enable = true;
      settings = {
        animations = true;
        animation-stiffness = 300.0;
        animation-dampening = 35.0;
        animation-clamping = false;
        animation-mass = 1;
        animation-for-workspace-switch-in = "auto";
        animation-for-workspace-switch-out = "auto";
        animation-for-open-window = "slide-down";
        animation-for-menu-window = "none";
        animation-for-transient-window = "slide-down";
        corner-radius = 12;
        rounded-corners-exclude = [
          "class_i = 'polybar'"
          "class_g = 'i3lock'"
        ];
        round-borders = 3;
        round-borders-exclude = [];
        round-borders-rule = [];
        shadow = true;
        shadow-radius = 8;
        shadow-opacity = 0.4;
        shadow-offset-x = -8;
        shadow-offset-y = -8;
        fading = false;
        inactive-opacity = 0.8;
        frame-opacity = 0.7;
        inactive-opacity-override = false;
        active-opacity = 1.0;
        focus-exclude = [
        ];

        opacity-rule = [
          "100:class_g = 'i3lock'"
          "60:class_g = 'Dunst'"
          "100:class_g = 'Alacritty' && focused"
          "90:class_g = 'Alacritty' && !focused"
        ];

        blur-kern = "3x3box";
        blur = {
          method = "kernel";
          strength = 8;
          background = false;
          background-frame = false;
          background-fixed = false;
          kern = "3x3box";
        };

        shadow-exclude = [
          "class_g = 'Dunst'"
        ];

        blur-background-exclude = [
          "class_g = 'Dunst'"
        ];

        backend = "glx";
        vsync = false;
        mark-wmwin-focused = true;
        mark-ovredir-focused = true;
        detect-rounded-corners = true;
        detect-client-opacity = false;
        detect-transient = true;
        detect-client-leader = true;
        use-damage = true;
        log-level = "info";

        wintypes = {
          normal = { fade = true; shadow = false; };
          tooltip = { fade = true; shadow = false; opacity = 0.75; focus = true; full-shadow = false; };
          dock = { shadow = false; };
          dnd = { shadow = false; };
          popup_menu = { opacity = 1.0; };
          dropdown_menu = { opacity = 1.0; };
        };
      };
    };

    # Let's be able to SSH into this machine
    # openssh.enable = true;

    # My editor runs as a daemon
    # emacs = {
    #   enable = true;
    #   package = pkgs.emacs-unstable;
    # };

    gvfs.enable = true; # Mount, trash, and other functionalities
    tumbler.enable = true; # Thumbnail support for images
  };

  # systemd.user.services.emacs = {
  #   serviceConfig.TimeoutStartSec = "7min";
  # };

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
  # virtualisation = {
  #   docker = {
  #     enable = true;
  #     logDriver = "json-file";
  #   };
  # };

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
    extraRules = [{
      commands = [
       {
         command = "${pkgs.systemd}/bin/reboot";
         options = [ "NOPASSWD" ];
        }
      ];
      groups = [ "wheel" ];
    }];
  };

  fonts.packages = with pkgs; [
    jetbrains-mono
    font-awesome
    noto-fonts
    noto-fonts-emoji
  ];

  environment.systemPackages = with pkgs; [
    gitAndTools.gitFull
    inetutils
  ];

  system.stateVersion = "21.05"; # Don't change this
}
