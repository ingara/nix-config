{ config, lib, ... }:
{
  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "zap";
      autoUpdate = false;
      # Activation must not depend on third-party CDNs. `brew bundle` runs
      # before home-manager activation under `set -e`, so one cask failing to
      # download aborts the switch and silently skips every home-manager
      # change. Upgrade deliberately with `brew upgrade` instead.
      upgrade = false;
    };
    global = {
      brewfile = true;
      autoUpdate = false;
    };
    casks = [
      "1password"
      "arc"
      "balenaetcher" # flash ISOs to USB (not in nixpkgs — removed over old-Electron CVEs)
      "bettertouchtool"
      "claude"
      "codex-app" # OpenAI Codex desktop app (GUI; CLI comes from codex-cli-nix)
      # AI usage meters + widgets.
      # A cask rather than nixpkgs' package because macOS ties Keychain grants
      # to the bundle path, and a store path moves on every bump.
      "codexbar"
      "conductor"
      "cursor"
      "cursor-cli"
      "discord"
      "element"
      "elgato-stream-deck"
      "fedora-media-writer"
      "figma"
      "firefox"
      "ghostty" # config + theming: shared/home/ghostty.nix (programs.ghostty, package=null on darwin)
      "google-chrome"
      "jordanbaird-ice@beta"
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

      # skhd.zig — hotkey daemon
      "skhd-zig"

      # SF Mono font for sketchybar
      "font-sf-mono"
      "font-sf-pro"
      "sf-symbols"
    ];
    brews = [
      "graphite"
      "switchaudio-osx"
    ];
    # Brewfile `trusted: true` on each non-official tap satisfies brew's tap
    # trust gate without `brew trust` state, which `brew bundle` cleanup deletes
    # mid-activation. Short-named brews and casks inherit trust from their tap.
    taps = map (
      key:
      let
        name = builtins.replaceStrings [ "homebrew-" ] [ "" ] key;
      in
      {
        inherit name;
        trusted = !lib.hasPrefix "homebrew/" name;
      }
    ) (builtins.attrNames config.nix-homebrew.taps);
    masApps = {
      "Amphetamine" = 937984704;
      "Balance Lock" = 1019371109;
      "Canary Mail App" = 1236045954;
      "Infuse • Video Player" = 1136220934;
      "System Color Picker" = 1545870783;
      "Timepage" = 989178902;
    };
  };
}
