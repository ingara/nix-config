# Personal Fish session authority and host mutation.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.myOptions) executionIdentity hasGui;
in
{
  assertions = [
    {
      assertion = executionIdentity == "personal";
      message = ''
        fish-session-personal.nix contains personal-only session integrations
        and requires executionIdentity = "personal"
      '';
    }
  ];

  # Keep this after portable initialization (priority 1000).
  programs.fish.shellInit = lib.mkOrder 1100 ''
    ${lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
      eval "$(/opt/homebrew/bin/brew shellenv)"
    ''}
    ${lib.optionalString (!hasGui) ''
      # Keep SSH agent forwarding working inside tmux.
      # On SSH login the real socket path is saved to a stable symlink;
      # inside a tmux session we always point at that symlink.
      if set -q SSH_AUTH_SOCK; and not set -q TMUX
        ln -sf $SSH_AUTH_SOCK ~/.ssh/agent.sock
      end
      set -gx SSH_AUTH_SOCK ~/.ssh/agent.sock
    ''}
  '';
}
