# Claude Code's config dir for GUI-launched processes.
#
# `environment.variables.CLAUDE_CONFIG_DIR` (shared/system/ai/claude-code.nix)
# only reaches shell init, so a GUI app that shells out to `claude` — a menu bar
# usage probe, the desktop app — sees nothing and falls back to ~/.claude,
# quietly building a second live config tree there. `launchctl setenv` covers
# the GUI session too.
#
# Lives here rather than beside the env var because a `mkIf isDarwin` would
# still declare `launchd`, which NixOS has no option for.
{ config, ... }:

let
  configDir = "${config.users.users.${config.system.primaryUser}.home}/.config/claude";
in
{
  # Applied by activation, so a switch reaches processes started after it
  # without a logout; an already-running app still needs a restart. The value is
  # single-quoted into `launchctl setenv`, so it must be a literal path —
  # `$HOME` would go through verbatim.
  launchd.user.envVariables.CLAUDE_CONFIG_DIR = configDir;

  # That activation runs only on an interactive switch, and `launchctl setenv`
  # state lives in the launchd session it ran against — so the variable is gone
  # after a reboot, and every GUI-launched `claude` is back to ~/.claude until
  # the next switch. Re-apply it at login.
  launchd.user.agents.claude-config-dir.serviceConfig = {
    ProgramArguments = [
      "/bin/launchctl"
      "setenv"
      "CLAUDE_CONFIG_DIR"
      configDir
    ];
    RunAtLoad = true;
  };
}
