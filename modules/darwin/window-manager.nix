{ config, lib, ... }:

let
  cfg = config.myOptions.windowManager;
in
{
  config = lib.mkIf (lib.elem "omniwm" cfg.enabled) {
    homebrew.casks = [ "omniwm" ];

    # OmniWM is an LSUIElement app: start it through LaunchServices so it keeps
    # its Accessibility grant. A launchd agent running the bundle binary
    # directly would lose that context. Its own login item (SMAppService) is a
    # Settings toggle, so it is not declarative. `open` returns immediately;
    # for a running OmniWM it only sends a reopen event.
    launchd.user.agents.omniwm.serviceConfig = {
      ProgramArguments = [
        "/usr/bin/open"
        "-a"
        "/Applications/OmniWM.app"
      ];
      RunAtLoad = true;
      StandardOutPath = "/tmp/omniwm-launch.log";
      StandardErrorPath = "/tmp/omniwm-launch.log";
    };
  };
}
