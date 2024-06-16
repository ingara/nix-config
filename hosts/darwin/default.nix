{ config, pkgs, ... }:

let
  user = "ingar";

  # To find key codes:
  #
  # Find hex value from: https://developer.apple.com/library/archive/technotes/tn2450/_index.html#//apple_ref/doc/uid/DTS40017618-CH1-KEY_TABLE_USAGES
  # For exmple 'Keyboard \ and |' has hex code 0x31
  # bash/zsh:
  #   $ printf '%d\n' "$(( 0x700000000 | 0x31 ))"
  #   30064771121
  keycodes = {
    backspace = 30064771114;
    pipe = 30064771121;
  };
in
{
  imports = [
    ../../modules/darwin/home-manager.nix
      ../../modules/shared
  ];


  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;

  # Setup user, packages, programs
  nix = {
    useDaemon = true;
    package = pkgs.nixVersions.latest;
    settings = {
      trusted-users = [ "@admin" "${user}" ];
      experimental-features = [ "nix-command" "flakes" ];
    };

    gc = {
      user = "root";
      automatic = true;
      interval = { Weekday = 0; Hour = 2; Minute = 0; };
      options = "--delete-older-than 30d";
    };


    # Turn this on to make command line easier
    # extraOptions = ''
    #   extra-platforms = aarch64-darwin x86_64-darwin
    #   experimental-features = nix-command flakes
    # '';
  };


  environment.shells = [pkgs.fish];
  programs.fish.enable = true;
  users.users.${user}.shell = pkgs.fish;

  # Turn off NIX_PATH warnings now that we're using flakes
  system.checks.verifyNixPath = false;

  # Load configuration that is shared across systems
  environment.systemPackages = import ../../modules/shared/packages.nix { inherit pkgs; };

  # TODO: set EDITOR etc?

  system = {
    keyboard = {
      enableKeyMapping = true;
      # use caps lock as escape
      remapCapsLockToEscape = true;
      userKeyMapping = [
        ({
          HIDKeyboardModifierMappingDst = keycodes.backspace;
          HIDKeyboardModifierMappingSrc = keycodes.pipe;
        })
        ({
          HIDKeyboardModifierMappingDst = keycodes.pipe;
          HIDKeyboardModifierMappingSrc = keycodes.backspace;
        })
      ];
    };
    defaults = {
      NSGlobalDomain = {
        AppleMeasurementUnits = "Centimeters";
        AppleMetricUnits = 1;
        AppleTemperatureUnit = "Celsius";
        AppleInterfaceStyle = "Dark";
        # expand the save panel by default
        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;
        # Disable automatic typography options I find annoying while typing code
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
        # Spelling correction is annoying
        NSAutomaticSpellingCorrectionEnabled = false;
        # enable tap-to-click (mode 1)
        "com.apple.mouse.tapBehavior" = 1;
        # Enable full keyboard access for all controls
        # (e.g. enable Tab in modal dialogs)
        AppleKeyboardUIMode = 3;
        # Disable press-and-hold for keys in favor of key repeat
        ApplePressAndHoldEnabled = false;
        # Set a very fast keyboard repeat rate
        KeyRepeat = 3;
        InitialKeyRepeat = 40;
        # Enable subpixel font rendering on non-Apple LCDs
        # Reference: https://github.com/kevinSuttle/macOS-Defaults/issues/17#issuecomment-266633501
        AppleFontSmoothing = 1;
        # Finder: show all filename extensions
        AppleShowAllExtensions = true;
      };

      finder = {
        # show full POSIX path as Finder window title
        _FXShowPosixPathInTitle = true;
        # disable the warning when changing a file extension
        FXEnableExtensionChangeWarning = false;
        # Show all files
        AppleShowAllFiles = true;
        # Show bottom status bar
        ShowStatusBar = true;
        ShowPathbar = true;
        # Default to list view
        FXPreferredViewStyle = "Nlsv";
      };

      trackpad = {
        Clicking = true;
        TrackpadThreeFingerDrag = false;
      };

      dock = {
        # set the icon size of all dock items
        tilesize = 30;
        # enable spring loading (hold a dragged file over an icon to drop/open it there)
        enable-spring-load-actions-on-all-items = true;
        # show indicator lights for open applications
        show-process-indicators = true;
        # don't automatically rearrange spaces based on the most recent one
        mru-spaces = false;
        # show hidden applications as translucent
        showhidden = true;
        # show only open apps
        static-only = true;
        # autohide instantly
        autohide = true;
        autohide-delay = 0.0;
        autohide-time-modifier = 0.4;
        orientation = "bottom";
        mouse-over-hilite-stack = true;
      };

      LaunchServices = {
        # Disable the "Are you sure you want to open this application?" dialog
        LSQuarantine = false;
      };
    };
  };
}
