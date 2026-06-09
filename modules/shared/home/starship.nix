# Starship prompt configuration.
#
# Powerline-style prompt inspired by powerlevel10k classic preset.
# Settings (format string + segment attrs) live inline as a `let`
# binding so moving the file doesn't require threading through a
# sibling helper. Colors come from the active base16 palette via
# `config.lib.stylix.colors`; segments use a shared pill-edge helper
# to keep the render consistent across language-version/git segments.
{ config, lib, ... }:

let
  c = config.lib.stylix.colors.withHashtag;

  # base16 mapping (matches stylix's standard slot semantics):
  #   bg          base01  — lighter background, used as pill body
  #   fg_overlay  base03  — comments/separators
  #   fg_blue     base0D
  #   fg_mauve    base0E
  #   fg_yellow   base0A
  #   fg_green    base0B
  #   fg_red      base08
  #   fg_text     base05
  bg = c.base01;
  fg_overlay = c.base03;
  fg_blue = c.base0D;
  fg_mauve = c.base0E;
  fg_yellow = c.base0A;
  fg_green = c.base0B;
  fg_red = c.base08;
  fg_text = c.base05;

  # Separator character
  sep = "/";

  # Helper to create separator format
  mkSep = "[${sep}](bg:${bg} fg:${fg_overlay})";

  # Helper to create segment format
  mkSegment = text: color: "[ ${text} ](bg:${bg} fg:${color})";

  # Helper to create pill start (left rounded edge)
  mkPillStart = "[](fg:${bg})";

  # Helper to create pill end (right rounded edge)
  mkPillEnd = "[](fg:${bg})";

  starshipSettings = {
    # Add blank line before prompt for breathing room
    add_newline = true;

    # Left side: line connector, directory, git info (in one pill)
    # Right side: cmd_duration, language versions, time (in one pill)
    format = lib.concatStrings [
      "[╭─](bold green)"
      mkPillStart
      "$username"
      "$hostname"
      "$directory"
      "$git_branch"
      "$git_status"
      mkPillEnd
      "$fill"
      mkPillStart
      "$cmd_duration"
      "$nodejs"
      "$rust"
      "$python"
      "$nix_shell"
      "$time"
      mkPillEnd
      "$line_break"
      "[╰─](bold green)$character"
    ];

    # Fill space between left and right
    fill = {
      symbol = " ";
    };

    # Username (only shown on SSH / root)
    username = {
      show_always = false;
      format = "[$user](bg:${bg} fg:${fg_green})[@](bg:${bg} fg:${fg_overlay})";
    };

    # Hostname (only shown on SSH)
    hostname = {
      ssh_only = true;
      format = "[$hostname](bg:${bg} fg:${fg_green})[${sep}](bg:${bg} fg:${fg_overlay})";
    };

    # Directory
    directory = {
      truncation_length = 5;
      truncation_symbol = "…/";
      truncate_to_repo = false;
      format = "[ $path ](bg:${bg} fg:${fg_blue})";
      substitutions = {
        "Documents" = "󰈙";
        "Downloads" = "󰇚";
        "Music" = "󰎆";
        "Pictures" = "󰋩";
        "dev" = "󰈮";
      };
    };

    # Git branch
    git_branch = {
      format = "${mkSep}${mkSegment "$symbol$branch(:$remote_branch)" fg_mauve}";
      symbol = " ";
    };

    # Git status with counts (only shown when dirty)
    git_status = {
      format = "(${mkSep}${mkSegment "$all_status$ahead_behind" fg_yellow})";
      conflicted = "🏳";
      ahead = "⇡ \${count}";
      behind = "⇣ \${count}";
      diverged = "⇕ ⇡ \${ahead_count} ⇣ \${behind_count}";
      up_to_date = "";
      untracked = "?\${count}";
      stashed = "📦";
      modified = "!\${count}";
      staged = "+\${count}";
      renamed = "»\${count}";
      deleted = "✘\${count}";
    };

    # Command duration (right side, only for slow commands >2s)
    cmd_duration = {
      min_time = 2000;
      format = "${mkSegment "󰔟 $duration" fg_yellow}";
    };

    # Node.js version
    nodejs = {
      format = "${mkSep}${mkSegment "$symbol$version" fg_green}";
      symbol = " ";
      detect_files = [
        "package.json"
        ".node-version"
        ".nvmrc"
      ];
    };

    # Rust version
    rust = {
      format = "${mkSep}${mkSegment "$symbol$version" fg_red}";
      symbol = "󱘗 ";
    };

    # Python version
    python = {
      format = "${mkSep}${mkSegment "$symbol$pyenv_prefix$version" fg_yellow}";
      symbol = " ";
    };

    # Nix shell indicator
    nix_shell = {
      format = "${mkSep}${mkSegment "$symbol$state( \\($name\\))" fg_blue}";
      symbol = " ";
    };

    # Time
    time = {
      disabled = false;
      format = "${mkSep}${mkSegment "󰥔 $time" fg_text}";
      time_format = "%H:%M";
    };

    # Shell indicator
    shell = {
      disabled = false;
      fish_indicator = "🐟";
      zsh_indicator = "𝓏";
    };

    # Character changes on success/failure
    character = {
      success_symbol = "[❯](bold green)";
      error_symbol = "[❯](bold red)";
    };
  };
in
{
  # https://nix-community.github.io/home-manager/options.xhtml#opt-programs.starship.enable
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    enableTransience = false;

    settings = starshipSettings;
  };
}
