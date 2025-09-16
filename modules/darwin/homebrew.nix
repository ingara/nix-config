{ config, ... }:
{
  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "zap";
      autoUpdate = true;
      upgrade = true;
    };
    global = {
      brewfile = true;
      autoUpdate = true;
    };
    casks = [
      "firefox"
      "firefox@developer-edition"
      "zen-browser"
      "spotify"
      "raycast"
      "shottr" # screenshot tool
      "hammerspoon"
      "notion"
      "discord"
      "visual-studio-code"
      "google-chrome"
      "istat-menus"
      "rapidapi"
      "1password"
      "elgato-stream-deck"
      "signal"
      "tidal"
      "slack"
      "whatsapp"
      "todoist"
      "chatgpt"
      "postico"
      "vial"
      "qmk-toolbox"
      "protonvpn"
      "arc"
      "karabiner-elements"
      "zoom"
      "mac-mouse-fix"
      "steam"
      "notion-calendar"
      "cursor"
      "cursor-cli"
      "steermouse"
      "ghostty"

      # SF Mono font for sketchybar
      "sf-symbols"
      "font-sf-mono"
      "font-sf-pro"
    ];
    brews = [
      "livekit"
    ];
    taps = map (key: builtins.replaceStrings [ "homebrew-" ] [ "" ] key) (
      builtins.attrNames config.nix-homebrew.taps
    );
    masApps = {
      Fantastical = 975937182;
      "Airmail 5" = 918858936;
      "Amphetamine" = 937984704;
      "Spotica Menu" = 570549457;
      "Balance Lock" = 1019371109;
      "Velja" = 1607635845;
      "Infuse • Video Player" = 1136220934;
    };
  };
}
