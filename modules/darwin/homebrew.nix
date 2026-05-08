{ config, ... }:
{
  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "zap";
      autoUpdate = false;
      upgrade = true;
    };
    global = {
      brewfile = true;
      autoUpdate = false;
    };
    casks = [
      "1password"
      "arc"
      "bettertouchtool"
      "claude"
      "cursor"
      "cursor-cli"
      "discord"
      "element"
      "elgato-stream-deck"
      "fedora-media-writer"
      "figma"
      "firefox"
      "ghostty"
      "google-chrome"
      "jordanbaird-ice@beta"
      "karabiner-elements"
      "lookaway"
      "notion"
      "obsidian"
      "postico"
      "protonvpn"
      "qmk-toolbox"
      "rapidapi"
      "raycast"
      "shottr" # screenshot tool
      "signal"
      "slack"
      "spotify"
      "steam"
      "steermouse"
      "tailscale-app"
      "tidal"
      "upscayl"
      "vial"
      "visual-studio-code"
      "whatsapp"
      "zen"
      "zoom"

      # SF Mono font for sketchybar
      "font-sf-mono"
      "font-sf-pro"
      "sf-symbols"
    ];
    brews = [
      "graphite"
      "switchaudio-osx"
      "wtp"
    ];
    taps = map (key: builtins.replaceStrings [ "homebrew-" ] [ "" ] key) (
      builtins.attrNames config.nix-homebrew.taps
    );
    masApps = {
      "Amphetamine" = 937984704;
      "Balance Lock" = 1019371109;
      "Infuse • Video Player" = 1136220934;
      "System Color Picker" = 1545870783;
    };
  };
}
