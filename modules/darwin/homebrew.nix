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
      "1password"
      "arc"
      "chatgpt"
      "claude"
      "cursor"
      "cursor-cli"
      "discord"
      "elgato-stream-deck"
      "firefox"
      "firefox@developer-edition"
      "ghostty"
      "google-chrome"
      "hammerspoon"
      "istat-menus"
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
      "tidal"
      "todoist-app"
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
      "livekit"
      "wtp"
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
