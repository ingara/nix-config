{ config, ... }:
{
  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "zap";
      autoUpdate = false;
      upgrade = false;
    };
    global = {
      brewfile = true;
      autoUpdate = false;
    };
    casks = [
      "1password"
      "arc"
      "bettertouchtool"
      "boring-notch"
      "chatgpt"
      "claude"
      "cursor"
      "cursor-cli"
      "discord"
      "elgato-stream-deck"
      "firefox"
      "ghostty"
      "google-chrome"
      "karabiner-elements"
      "lookaway"
      "mac-mouse-fix"
      "notion"
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
      "todoist-app"
      "vial"
      "visual-studio-code"
      "whatsapp"
      "windsurf"
      "zen"
      "zoom"

      # SF Mono font for sketchybar
      "font-sf-mono"
      "font-sf-pro"
      "sf-symbols"
    ];
    brews = [
      "graphite"
      "livekit"
      "switchaudio-osx"
      "wtp"
    ];
    taps = map (key: builtins.replaceStrings [ "homebrew-" ] [ "" ] key) (
      builtins.attrNames config.nix-homebrew.taps
    );
    masApps = {
      Fantastical = 975937182;
      "Airmail 5" = 918858936;
      "Amphetamine" = 937984704;
      "Balance Lock" = 1019371109;
      "Infuse • Video Player" = 1136220934;
      "System Color Picker" = 1545870783;
    };
  };
}
