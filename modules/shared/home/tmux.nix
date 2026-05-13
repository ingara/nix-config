# Tmux multiplexer configuration.
#
# Plugins cover pane navigation, prefix-highlight, sidebar, fzf, battery,
# URL finder. Theme/status colors come from `stylix.targets.tmux`
# (wired per-platform). The vim-tmux-navigator binding detects nested
# vim processes so C-hjkl transparently selects panes or moves cursor
# inside vim.
{ pkgs, ... }:

{
  programs.tmux = {
    enable = true;

    clock24 = true;
    escapeTime = 0;
    keyMode = "vi";
    shortcut = "a";
    plugins = with pkgs.tmuxPlugins; [
      open # Open stuff with prefix+o
      pain-control # navigating panes etc
      prefix-highlight
      sidebar # prefix+<tab> and prefix+<backspace>
      tmux-fzf # prefix+F
      # tmux-thumbs # copy/pasting stuff. prefix+<space>
      battery
      vim-tmux-navigator # Move around with <ctrl>+hjkl
      yank # Copy to system clipboard
      fzf-tmux-url # Find URLS with prefix+u
    ];
    # extraConfig = (builtins.readFile ../../../configs/tmux.conf);
    extraConfig = ''
      # True color settings
      set -g default-terminal "tmux-256color"
      # set -ag terminal-overrides ",xterm-256color:RGB"

      # Or use a wildcard instead of forcing a default mode.
      # Some users in the comments of this gist have reported that this work better.
      set -sg terminal-overrides ",*:RGB"

      # You can also use the env variable set from the terminal.
      # Useful if you share your configuration betweeen systems with a varying value.
      #set -ag terminal-overrides ",$TERM:RGB"

      set -g mouse on
      setw -g mouse on
      set-option -g default-shell $SHELL

      set -g status-position bottom

      # vim/fzf tmux integration
      # https://github.com/christoomey/vim-tmux-navigator/issues/295#issuecomment-1021591011
      is_vim="children=(); i=0; pids=( $(ps -o pid=,tty= | grep -iE '#{s|/dev/||:pane_tty}' | awk '\{print $1\}') ); \
      while read -r c p; do [[ -n c && c -ne p && p -ne 0 ]] && children[p]+=\" $\{c\}\"; done <<< \"$(ps -Ao pid=,ppid=)\"; \
      while (( $\{#pids[@]\} > i )); do pid=$\{pids[i++]\}; pids+=( $\{children[pid]-\} ); done; \
      ps -o state=,comm= -p \"$\{pids[@]\}\" | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|n?vim?x?)(diff)?$'"

      bind -n C-h run "($is_vim && tmux send-keys C-h) || tmux select-pane -L"
      bind -n C-j run "($is_vim && tmux send-keys C-j) || tmux select-pane -D"
      bind -n C-k run "($is_vim && tmux send-keys C-k) || tmux select-pane -U"
      bind -n C-l run "($is_vim && tmux send-keys C-l) || tmux select-pane -R"

      # Reload config with r
      bind r source-file ~/.config/tmux/tmux.conf \; display-message "tmux.conf reloaded"
    '';
  };
}
