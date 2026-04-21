{
  config,
  pkgs,
  inputs,
  ...
}:

let
  user = config.myOptions.user.username;

  # To find key codes:
  #
  # Find hex value from: https://developer.apple.com/library/archive/technotes/tn2450/_index.html#//apple_ref/doc/uid/DTS40017618-CH1-KEY_TABLE_USAGES
  # For exmple 'Keyboard \ and |' has hex code 0x31
  # bash/zsh:
  #   $ printf '%d\n' "$(( 0x700000000 | 0x31 ))"
  #   30064771121
in
{
  imports = [
    ../../modules/darwin/home-manager.nix
    ../../modules/shared
    ../../modules/darwin/homebrew.nix
  ];

  myOptions = {
    hasGui = true;
    sshSignProgram = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
    gitCredentialHelper = "osxkeychain";
  };

  # Window manager selection: "yabai", "aerospace", or "none"
  # Change to "aerospace" to switch to AeroSpace window manager
  myOptions.windowManager.backend = "aerospace";

  # The default Nix build user group ID was changed from 30000 to 350.
  # You are currently managing Nix build users with nix-darwin, but your
  # nixbld group has GID 30000, whereas we expected 350.
  #
  # Possible causes include setting up a new Nix installation with an
  # existing nix-darwin configuration, setting up a new nix-darwin
  # installation with an existing Nix installation, or manually increasing
  # your `system.stateVersion` setting.
  #
  # You can set the configured group ID to match the actual value:
  #
  #     ids.gids.nixbld = 30000;
  #
  # We do not recommend trying to change the group ID with macOS user
  # management tools without a complete uninstallation and reinstallation
  # of Nix.
  ids.gids.nixbld = 30000;

  # Setup user, packages, programs
  nix = {
    enable = true;
    package = pkgs.nixVersions.latest;
    settings = {
      # Only the primary user is trusted for privileged Nix operations
      # (custom substituters, signing store paths, unsandboxed builds).
      # Removed `@admin` so a second admin user couldn't poison the store.
      trusted-users = [ "${user}" ];
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };

    gc = {
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 2;
        Minute = 0;
      };
      options = "--delete-older-than 30d";
    };
  };

  environment.shells = [ pkgs.fish ];
  programs.fish.enable = true;
  users.users.${user}.shell = pkgs.fish;

  # Load configuration that is shared across systems
  environment.systemPackages = import ../../modules/shared/packages.nix { inherit pkgs; } ++ [
    inputs.claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
    inputs.aerospace-scratchpad.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  system = {
    stateVersion = 5;
    # Turn off NIX_PATH warnings now that we're using flakes
    checks.verifyNixPath = false;
    primaryUser = user;
    keyboard = {
      enableKeyMapping = false; # using karabiner-elements
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

        "com.apple.keyboard.fnState" = true; # Use F1, F2, etc. keys as standard function keys.
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
        magnification = true;
        largesize = 64;
      };

      LaunchServices = {
        # Disable the "Are you sure you want to open this application?" dialog
        LSQuarantine = false;
      };
    };
  };

  # macOS Application Layer Firewall. Codifies the firewall on-state so
  # it survives reinstalls / replicates to new machines. Stealth mode
  # silently drops ICMP / port scans (side effect: `ping` to this Mac
  # from other devices fails — Bonjour/AirDrop/screen-share still work
  # because they use TCP/multicast UDP, not ICMP).
  #
  # No declarative logging knob: macOS 15+ removed
  # `socketfilterfw --setloggingmode`; ALF events go to unified logging
  # by default. Query with:
  #   log show --last 1h --predicate 'subsystem == "com.apple.alf"' --info
  networking.applicationFirewall = {
    enable = true;
    allowSigned = true; # signed Apple/system processes may accept incoming
    allowSignedApp = true; # signed downloaded apps may accept incoming
    blockAllIncoming = false;
    enableStealthMode = true;
  };

  # FileVault check — warns at activation if full-disk encryption is OFF.
  # FileVault can't be enabled declaratively (needs a user password); this
  # nag motivates re-enabling if it ever lapses. Lives in `postActivation`
  # because nix-darwin only invokes a fixed list of activation-script
  # keys (custom names like `checkFileVault` are silently ignored, unlike
  # NixOS).
  system.activationScripts.postActivation.text = ''
    if ! /usr/bin/fdesetup status 2>/dev/null | grep -q "FileVault is On"; then
      echo "WARNING: FileVault is not enabled" >&2
    fi
  '';
}
