{
  config,
  pkgs,
  lib,
  userConfig,
  ...
}:

let
  # Use centralized user configuration from flake
  name = userConfig.fullName;
  user = userConfig.username;
  inherit (userConfig) email;
  homeDir = if pkgs.stdenv.isDarwin then "/Users/${user}" else "/home/${user}";
  aliases = {
    cat = "bat";
    g = "git";
    tls = "tmux-lazy-session";
    tf = "terraform";
    lg = "lazygit";
    kubectl = "kubecolor";
    br = "broot";
    vim = "nvim";
    top = "btm"; # Use bottom instead of top

    # Eza stuff
    ls = "eza";
    l = "eza -l --all --group-directories-first --git";
    ll = "eza -l --all --all --group-directories-first --git";
    lt = "eza -T --git-ignore --level=2 --group-directories-first";
    llt = "eza -lT --git-ignore --level=2 --group-directories-first";
    lT = "eza -T --git-ignore --level=4 --group-directories-first";

    cdg = "cd $(git rev-parse --show-toplevel)";

    # Global just alias for soolv project
    s = "soolv";
  };
in
{
  direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  fish = {
    enable = true;
    shellAliases = aliases;
    shellInit = ''
      ${lib.optionalString pkgs.stdenv.isDarwin ''
        eval "$(/opt/homebrew/bin/brew shellenv)"
      ''}
      fish_add_path -g $HOME/go/bin
      set -gx GOPRIVATE "github.com/soolv/*"

      if command -q soolv
        soolv shell-init fish | source
      end
      # Disable greeting
      set -g fish_greeting

      # Pager configuration
      # set -gx PAGER less
      # set -gx LESS "-R --quit-if-one-screen --no-init"

      ${lib.optionalString pkgs.stdenv.isDarwin ''
        # MacOS ALT+d fzf
        bind "∂" fzf-cd-widget

        # Shift+Enter for newline in zellij
        bind \eSE 'commandline -i \n'

        # wtp shell integration
        if command -q wtp
          wtp shell-init fish | source
        end
      ''}

      # Completion for soolv (global just alias)
      complete -c soolv -f -a "(just --justfile ${homeDir}/dev/soolv/justfile --summary 2>/dev/null | tr ' ' '\n')"
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

  zsh = {
    enable = true;
    autocd = false;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    cdpath = [ "~/.local/share/src" ];
    shellAliases = aliases;
    oh-my-zsh = {
      enable = true;
      theme = "bira";
      plugins = [
        "git"
        "sudo"
        "colorize"
        "kubectl"
      ];
    };
    initContent =
      lib.optionalString pkgs.stdenv.isDarwin ''
        # wtp shell integration
        if command -v wtp &> /dev/null; then
          eval "$(wtp completion zsh)"
        fi
      ''
      + ''
        # n function for nvim
        function n() {
          if [ $# -eq 0 ]; then
            nvim .
          else
            nvim "$@"
          fi
        }

        # Zoxide interactive mode (fuzzy search directories)
        function zi() {
          local result=$(zoxide query -l | fzf --height 40% --reverse --preview 'eza -la {}')
          [ -n "$result" ] && cd "$result"
        }
      '';
  };

  # https://nix-community.github.io/home-manager/options.xhtml#opt-programs.starship.enable
  starship = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    enableTransience = false;

    settings = import ./starship-settings.nix { inherit lib; };
  };

  gh = {
    enable = true;
  };

  git = {
    enable = true;
    ignores = [
      ".DS_Store"
      ".direnv"
      "shell.nix"
      ".envrc"
      "flake.lock"
      "flake.nix"
      ".pre-commit-config.yaml"
    ];

    signing = {
      signByDefault = true;
      key = userConfig.signingKey; # Centralized from flake config
    };

    settings = {
      user = {
        inherit name;
        inherit email;
      };
      core.editor = "nvim";
      init.defaultBranch = "main";
      pull = {
        default = "current";
        rebase = true;
      };
      push.default = "current";
      rerere.enabled = true;
      "filter \"lfs\"" = {
        process = "git-lfs filter-process";
        required = true;
        clean = "git-lfs clean -- %f";
        smudge = "git-lfs smudge -- %f";
      };
      gpg.format = "ssh";
      "url \"ssh://git@github.com/\"".insteadOf = "https://github.com/";
    }
    // lib.optionalAttrs pkgs.stdenv.isDarwin {
      credential.helper = "osxkeychain";
      "gpg \"ssh\"".program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
    }
    // lib.optionalAttrs pkgs.stdenv.isLinux {
      credential.helper = "store";
      "gpg \"ssh\"".program = "${pkgs._1password-gui}/bin/op-ssh-sign";
    };

    # Include all git config files from git-extra directory
    # To add more files: just add them to this list and to dotfiles/git-extra/
    includes = [
      { path = "~/.config/git/extra/aliases.gitconfig"; }
    ];
  };

  delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
      side-by-side = false;
      pager = "less";
      hyperlinks = true;
      keep-plus-minus-markers = true;
    };
  };

  bat = {
    enable = true;
  };

  fzf = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
  };

  ripgrep = {
    enable = true;
    arguments = [
      "--column"
      "--line-number"
      "--max-columns-preview"
      "--colors=line:style:bold"
    ];
  };

  alacritty = {
    enable = false;
  };
  wezterm = {
    enable = true;
    extraConfig = ''
      local config = require('extra.main')
      return config
    '';
  };

  zoxide = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
  };

  tmux = {
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

      set -g @catppuccin_status_modules_left ""
      set -g @catppuccin_status_modules_right "date_time uptime battery application session"
      set -g @catppuccin_status_justify "left"

      set -g @catppuccin_window_left_separator ""
      set -g @catppuccin_window_right_separator " "
      set -g @catppuccin_window_middle_separator " █"
      set -g @catppuccin_window_number_position "right"
      set -g @catppuccin_window_current_fill "number"
      set -g @catppuccin_window_default_fill "number"

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
