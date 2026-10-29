{ config, lib, ... }:
let
  hmUser = config.home-manager.users.${config.homebrew.user} or null;
in
{
  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "zap";
      # brew keeps its trust store under XDG_CONFIG_HOME when set, which
      # activation's sudo drops. Pass the user's value so `brew bundle` writes
      # the store the shell's brew reads.
      extraEnv = lib.mkIf (hmUser != null && hmUser.xdg.enable) {
        XDG_CONFIG_HOME = hmUser.xdg.configHome;
      };
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
      "discord"
      "element"
      "elgato-stream-deck"
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
      "raycast"
      "shottr" # screenshot tool
      "slack"
      "spotify"
      "steam"
      "steermouse"
      "tailscale-app"
      "vial"
      "visual-studio-code"
      "vivaldi"
      "whatsapp"
      "zen"

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
    # Brewfile `trusted: true` is the only effective trust. nix-homebrew's
    # `brew trust` step lacks extraEnv and writes a store the shell doesn't
    # read; `--force-cleanup` resets the shell's store to Brewfile entries
    # (zhaofengli/nix-homebrew#161).
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
