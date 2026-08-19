{ config, ... }:
{
  # Opt out of brew 6.x's non-official-tap trust gate. It's unworkable under
  # nix-darwin here: `brew bundle --zap --force-cleanup` (the activation step)
  # deletes trust.json mid-run, and its `sudo --set-home` strips XDG_CONFIG_HOME
  # so it reads ~/.homebrew while an interactive brew reads ~/.config/homebrew
  # (zhaofengli/nix-homebrew#161). The net effect is the gate refusing our taps
  # and aborting the switch whenever cleanup uninstalls anything. The tap
  # content is already pinned to reviewed commits via locked flake inputs
  # (mutableTaps = false), so the gate is redundant defence here. The launcher
  # sources this file before the trust check. A tracking issue holds the
  # procedure to re-test and re-enable once upstream resolves both the XDG split
  # and the deletion.
  environment.etc."homebrew/brew.env".text = "HOMEBREW_NO_REQUIRE_TAP_TRUST=1\n";

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
      # AI usage meters + widgets (GUI; CLI comes from overlays/codexbar.nix).
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
    taps = map (key: builtins.replaceStrings [ "homebrew-" ] [ "" ] key) (
      builtins.attrNames config.nix-homebrew.taps
    );
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
