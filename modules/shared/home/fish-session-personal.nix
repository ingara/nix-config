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
      # Keep SSH agent forwarding working in long-lived multiplexer panes.
      # On SSH login the forwarded socket is saved to a stable symlink, and
      # every shell points at that symlink. A nested shell inherits the
      # symlink itself as SSH_AUTH_SOCK, so only a live socket elsewhere is
      # linked; a broken link is removed so clients report no agent instead
      # of a symlink loop.
      set -l stable ~/.ssh/agent.sock
      if set -q SSH_AUTH_SOCK; and test "$SSH_AUTH_SOCK" != $stable; and test -S "$SSH_AUTH_SOCK"; and not set -q TMUX
        ln -sf $SSH_AUTH_SOCK $stable
      else if test -L $stable; and not test -e $stable
        rm $stable
      end
      set -gx SSH_AUTH_SOCK $stable
    ''}
  '';
}
