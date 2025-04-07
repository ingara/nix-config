{ config, pkgs, lib, ... }:

let
  name = "Ingar Mathisen Almklov";
  user = "ingar";
  email = "ingara@gmail.com";
  aliases = {
    cat = "bat";
    g = "git";
    dr = "darwin-rebuild";
    tls = "tmux-lazy-session";
    tf = "terraform";
    lg = "lazygit";
    kubectl = "kubecolor";
    br = "broot";
    vim = "nvim";

    # Eza stuff
    ls = "eza";
    l = "eza -l --all --group-directories-first --git";
    ll = "eza -l --all --all --group-directories-first --git";
    lt = "eza -T --git-ignore --level=2 --group-directories-first";
    llt = "eza -lT --git-ignore --level=2 --group-directories-first";
    lT = "eza -T --git-ignore --level=4 --group-directories-first";

    cdg = "cd $(git rev-parse --show-toplevel)";
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
      eval "$(/opt/homebrew/bin/brew shellenv)"
      # Disable greeting
      set -g fish_greeting

      # MacOS ALT+d fzf
      bind "∂" fzf-cd-widget
    '';
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
    initExtraFirst = ''
      # if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
      #   . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
      #   . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
      # fi

      # if [[ "$(uname)" == "Linux" ]]; then
      #   alias pbcopy='xclip -selection clipboard'
      # fi

      # # Remove history data we don't want to see
      # export HISTIGNORE="pwd:ls:cd"
    '';
  };

  # https://nix-community.github.io/home-manager/options.xhtml#opt-programs.starship.enable
  starship = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    enableTransience = true;

    catppuccin.enable = true;

    settings = {
      directory = {
        truncation_length = 5;
        truncation_symbol = "…/";
        truncate_to_repo = false;
        substitutions = {
          "Documents" = " ";
          "Downloads" = " ";
          "Music" = " ";
          "Pictures" = " ";
        };
      };

      shell = {
          disabled = false;
          fish_indicator = "🐟";
          zsh_indicator = "𝓏";
        };
    };
  };

  gh = {
    enable = true;
  };

  git = {
    enable = true;
    userName = name;
    userEmail = email;
    delta = {
      enable = true;
      catppuccin.enable = true;
      options = {
        line-numbers = true;
      };
    };
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
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF2vZOGuH6Eix++BVA093FnJvrjSa1aLa5v976xVsp5K";
    };



    extraConfig = {
      core.editor = "nvim";
      init.defaultBranch = "main";
      credential.helper = "osxkeychain";
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
      "gpg \"ssh\"".program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
    };

    aliases = {
      last = "log -1 --stat";
      c = "commit";
      ca = "commit --amend";
      cm = "commit -m";
      s = "status";
      br = "branch";
      d = "diff";
      dw = "diff -w";
      dc = "diff --cached";
      lg = "log --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %Cblue<%an>%Creset' --abbrev-commit --date=relative --all";
      lgg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %Cblue<%an>%Creset' --abbrev-commit --date=relative --all";

      # Restore file from last commit where it existed
      restore-file = ''!git checkout $(git rev-list -n 1 HEAD -- "$1")^ -- "$1"'';

      # From https://github.com/not-an-aardvark/git-delete-squashed
      delete-squashed = ''!f() { DEFAULT=$(git default); local targetBranch=''${1-$DEFAULT} && git checkout -q $targetBranch && git branch --merged | grep -v "\*" | xargs --no-run-if-empty -n 1 git branch -d && git for-each-ref refs/heads/ "--format=%(refname:short)" | while read branch; do mergeBase=$(git merge-base $targetBranch $branch) && [[ $(git cherry $targetBranch $(git commit-tree $(git rev-parse $branch^{tree}) -p $mergeBase -m _)) == "-"* ]] && git branch -D $branch; done; }; f'';
      # From https://github.com/haacked/dotfiles/blob/main/git/gitconfig.aliases.symlink
      delete-cleanmerged = ''!f() { DEFAULT=$(git default); git branch --merged ''${1-$DEFAULT} | grep -v " ''${1-$DEFAULT}$" | xargs --no-run-if-empty git branch -d; }; f'';

      # Haacked aliases - https://github.com/haacked/dotfiles/blob/main/git/gitconfig.aliases.symlink
      abort = "rebase --abort";
      aliases = "!git config -l | grep ^alias\\. | cut -c 7-";
      amend = "commit -a --amend";
      # Deletes all branches merged into the specified branch (or the default branch if no branch is specified)
      bclean = "!f() { DEFAULT=$(git default); git delete-cleanmerged \${1-$DEFAULT} && git delete-squashed \${1-$DEFAULT}; }; f";
      # Switches to specified branch (or the dafult branch if no branch is specified), runs git up, then runs bclean.
      bdone = "!f() { DEFAULT=$(git default); git checkout \${1-$DEFAULT} && git up && git bclean \${1-$DEFAULT}; }; f";
      # Lists all branches including remote branches
      branches = "branch -a";
      browse = "!git open";
      # Lists the files with the most churn
      churn = "!git --no-pager log --name-only --oneline | grep -v ' ' | sort | uniq -c | sort -nr | head";
      cleanup = "clean -xdf -e *.DotSettings* -e s3_keys.ps1";
      # Stages every file then creates a commit with specified message
      co = "checkout";
      cob = "checkout -b";
      # Show list of files in a conflict state.
      conflicts = "!git diff --name-only --diff-filter=U";
      cp = "cherry-pick";
      default = "!git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'";
      delete = "branch -d";
      # Discard changes to a file
      discard = "checkout --";
      find = "!git ls-files | grep -i";
      graph = "log --graph -10 --branches --remotes --tags  --format=format:'%Cgreen%h %Creset• %<(75,trunc)%s (%cN, %cr) %Cred%d' --date-order";
      grep = "grep -Ii";
      hist = "log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)' --all";
      history = "log --graph --abbrev-commit --decorate --date=relative --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)' --all";
      # Shows the commit message and files changed from the latest commit
      latest = "!git ll -1";
      lds = "log --pretty=format:'%C(yellow)%h\\ %ad%Cred%d\\ %Creset%s%Cblue\\ [%cn]' --decorate --date=short";
      lost = "fsck --lost-found";
      # A better git log.
      ls = "log --pretty=format:'%C(yellow)%h%Cred%d\\ %Creset%s%Cblue\\ [%cn]' --decorate";
      # Moves a set of commits from the current branch to another
      rba = "rebase --abort";
      rbc = "!f(){ git add -A && git rebase --continue; }; f";
      re = "!f(){ DEFAULT=$(git default); git fetch origin && git rebase origin/\${1-$DEFAULT}; }; f";
      remotes = "remote -v";
      restore = "!f(){ git add -A && git commit -qm 'RESTORE SAVEPOINT'; git reset $1 --hard; }; f";
      ri = "!f(){ DEFAULT=$(git default); git fetch origin && git rebase --interactive origin/\${1-$DEFAULT}; }; f";
      save = "!git add -A && git commit -m 'SAVEPOINT'";
      set-origin = "remote set-url origin";
      set-upstream = "remote set-url upstream";
      st = "status -s";
      stashes = "stash list";
      sync = "!git pull --rebase && git push";
      undo = "reset HEAD~1 --mixed";
      # Unstage a file
      unstage = "reset -q HEAD --";
      up = "!git pull --rebase --prune $@ && git submodule update --init --recursive";
      wip = "commit -am 'WIP'";
      wipe = "!f() { rev=$(git rev-parse \${1-HEAD}); git add -A && git commit --allow-empty -qm 'WIPE SAVEPOINT' && git reset $rev --hard; }; f";
    };
  };

  bat = {
    enable = true;
    catppuccin.enable = true;
  };

  fzf = {
    enable = true;
    catppuccin.enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    # changeDirWidgetCommand = "${pkgs.fd}/bin/fd --type d";
    # defaultCommand = "${pkgs.fd}/bin/fd --type file --hidden --exclude .git";
    # fileWidgetCommand = "${pkgs.fd}/bin/fd --type file --hidden --exclude .git";
    # fileWidgetOptions = [ "--preview '${pkgs.bat}/bin/bat --style=numbers --color=always {}'" ];
  };

  ripgrep = {
    enable = true;
    arguments = [ "--column" "--line-number" "--max-columns-preview" "--colors=line:style:bold" ];
  };

  neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
  };

  alacritty = {
    enable = true;
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
  };


  # TODO: use this?
  #
  # ssh = {
  #   enable = true;
  #
  #   extraConfig = lib.mkMerge [
  #     (lib.mkIf pkgs.stdenv.hostPlatform.isLinux
  #       ''
  #       Include /home/${user}/.ssh/config_external
  #       '')
  #     (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin
  #       ''
  #       Include /Users/${user}/.ssh/config_external
  #       '')
  #     ''
  #       Host github.com
  #         Hostname github.com
  #         IdentitiesOnly yes
  #     ''
  #     (lib.mkIf pkgs.stdenv.hostPlatform.isLinux
  #       ''
  #         IdentityFile /home/${user}/.ssh/id_github
  #       '')
  #     (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin
  #       ''
  #         IdentityFile /Users/${user}/.ssh/id_github
  #       '')
  #   ];
  # };


  tmux = {
    enable = true;

    catppuccin.enable = true;

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
