{ config, ... }:
{
  homebrew = {
    enable = true;
    casks = [
      "firefox"
      "firefox@developer-edition"
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
      "jordanbaird-ice"
      "whatsapp"
      "todoist"
      "chatgpt"
      "postico"
      "vial"
      "qmk-toolbox"
    ];
    brews = [
      "skhd"
      "yabai"
      "sketchybar"
    ];
    taps = map (key: builtins.replaceStrings ["homebrew-"] [""] key) (builtins.attrNames config.nix-homebrew.taps);
    masApps = {
      Fantastical = 975937182;
      "Airmail 5" = 918858936;
      "Amphetamine" = 937984704;
      "Spotica Menu" = 570549457;
      "Balance Lock" = 1019371109;
      "Velja" = 1607635845;
      "Canary Mail App" = 1236045954;
      "Infuse • Video Player" = 1136220934;
    };
  };
}
