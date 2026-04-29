# Fish shell configuration.
#
# Shared aliases live in `./aliases.nix` (also consumed by `./zsh.nix`).
# Shell init handles: homebrew shellenv on darwin, SSH_AUTH_SOCK stability
# inside multiplexers on headless hosts, orphaned zellij server cleanup
# on linux, and auto-attach-to-zellij when `myOptions.zellijAutoAttach`
# is true.
{
  pkgs,
  lib,
  config,
  ...
}:

let
  inherit (config.myOptions) hasGui zellijAutoAttach;
in
{
  programs.fish = {
    enable = true;
    shellAliases = import ./aliases.nix { };
    shellInit = ''
      ${lib.optionalString pkgs.stdenv.isDarwin ''
        eval "$(/opt/homebrew/bin/brew shellenv)"
      ''}
      fish_add_path -g $HOME/go/bin
      # Disable greeting
      set -g fish_greeting

      ${lib.optionalString (!hasGui) ''
        # Keep SSH agent forwarding working inside zellij/tmux.
        # On SSH login the real socket path is saved to a stable symlink;
        # inside a multiplexer session we always point at that symlink.
        if set -q SSH_AUTH_SOCK; and not set -q ZELLIJ; and not set -q TMUX
          ln -sf $SSH_AUTH_SOCK ~/.ssh/agent.sock
        end
        set -gx SSH_AUTH_SOCK ~/.ssh/agent.sock
      ''}

      ${lib.optionalString pkgs.stdenv.isLinux ''
        # Kill orphaned zellij servers whose sockets have disappeared.
        # Nix upgrades can change the binary path, orphaning old servers.
        # See: https://github.com/zellij-org/zellij/issues/3775
        if not set -q ZELLIJ
          for pid in (pgrep -f 'zellij --server' 2>/dev/null)
            set -l args (string split0 -- < /proc/$pid/cmdline 2>/dev/null)
            set -l idx (contains -i -- '--server' $args)
            and set -l socket $args[(math $idx + 1)]
            if test -n "$socket"; and not test -S "$socket"
              echo "Killing orphaned zellij server (PID $pid)"
              kill $pid
            end
          end
        end
      ''}

      ${lib.optionalString zellijAutoAttach ''
        # Auto-attach to zellij session (create if needed)
        if status is-interactive; and not set -q ZELLIJ
          exec zellij attach -c main
        end
      ''}

      # Pager configuration
      # set -gx PAGER less
      # set -gx LESS "-R --quit-if-one-screen --no-init"

      ${lib.optionalString pkgs.stdenv.isDarwin ''
        # MacOS ALT+d fzf
        bind "∂" fzf-cd-widget

        # Shift+Enter for newline (kitty keyboard protocol: \e[13;2u)
        bind \e\[13\;2u 'commandline -i \n'

        # wtp shell integration
        if command -q wtp
          wtp shell-init fish | source
        end
      ''}

    '';
    functions = {
      n = ''
        if test (count $argv) -eq 0
          nvim .
        else
          nvim $argv
        end
      '';
      # Zoxide interactive mode (fuzzy search directories)
      zi = ''
        set -l result (zoxide query -l | fzf --height 40% --reverse --preview 'eza -la {}')
        and cd $result
      '';
    };
  };
}
