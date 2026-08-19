# Starship prompt configuration.
#
# Powerline-style prompt inspired by powerlevel10k classic preset.
# Colors come from the active base16 palette via `config.lib.stylix.colors`.
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

  sep = "/";
  mkSep = "[${sep}](bg:${bg} fg:${fg_overlay})";
  mkSegment = text: color: "[ ${text} ](bg:${bg} fg:${color})";
  # Pill edges: left and right rounded caps around a segment group.
  mkPillStart = "[](fg:${bg})";
  mkPillEnd = "[](fg:${bg})";

  starshipSettings = {
    add_newline = true;

    # Left pill: line connector, directory, git info.
    # Right pill: cmd_duration, language versions, time.
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

    fill = {
      symbol = " ";
    };

    # Only shown on SSH / root.
    username = {
      show_always = false;
      format = "[$user](bg:${bg} fg:${fg_green})[@](bg:${bg} fg:${fg_overlay})";
    };

    # Only shown on SSH.
    hostname = {
      ssh_only = true;
      format = "[$hostname](bg:${bg} fg:${fg_green})[${sep}](bg:${bg} fg:${fg_overlay})";
    };

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

    git_branch = {
      format = "${mkSep}${mkSegment "$symbol$branch(:$remote_branch)" fg_mauve}";
      symbol = " ";
    };

    # Counts; only shown when dirty.
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

    # Only shown for commands slower than min_time (2s).
    cmd_duration = {
      min_time = 2000;
      format = "${mkSegment "󰔟 $duration" fg_yellow}";
    };

    nodejs = {
      format = "${mkSep}${mkSegment "$symbol$version" fg_green}";
      symbol = " ";
      detect_files = [
        "package.json"
        ".node-version"
        ".nvmrc"
      ];
    };

    rust = {
      format = "${mkSep}${mkSegment "$symbol$version" fg_red}";
      symbol = "󱘗 ";
    };

    python = {
      format = "${mkSep}${mkSegment "$symbol$pyenv_prefix$version" fg_yellow}";
      symbol = " ";
    };

    nix_shell = {
      format = "${mkSep}${mkSegment "$symbol$state( \\($name\\))" fg_blue}";
      symbol = " ";
    };

    time = {
      disabled = false;
      format = "${mkSep}${mkSegment "󰥔 $time" fg_text}";
      time_format = "%H:%M";
    };

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
