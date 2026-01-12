# Enhanced starship configuration with powerline style
# Inspired by powerlevel10k classic preset
{ lib }:
let
  # Catppuccin Mocha colors
  bg = "#313244"; # Surface0
  fg_overlay = "#6c7086"; # Overlay0 (for separators)
  fg_blue = "#89b4fa"; # Blue
  fg_mauve = "#cba6f7"; # Mauve
  fg_yellow = "#f9e2af"; # Yellow
  fg_green = "#a6e3a1"; # Green
  fg_red = "#f38ba8"; # Red
  fg_text = "#cdd6f4"; # Text

  # Separator character
  sep = "/";

  # Helper to create separator format
  mkSep = "[${sep}](bg:${bg} fg:${fg_overlay})";

  # Helper to create segment format
  mkSegment = text: color: "[ ${text} ](bg:${bg} fg:${color})";

  # Helper to create pill start (left rounded edge)
  mkPillStart = "[](fg:${bg})";

  # Helper to create pill end (right rounded edge)
  mkPillEnd = "[](fg:${bg})";
in
{
  # Add blank line before prompt for breathing room
  add_newline = true;

  # Left side: line connector, directory, git info (in one pill)
  # Right side: cmd_duration, language versions, time (in one pill)
  format = lib.concatStrings [
    "$username"
    "$hostname"
    "[╭─](bold green)"
    mkPillStart
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
    symbol = " ";
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
    symbol = " ";
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
    symbol = " ";
  };

  # Nix shell indicator
  nix_shell = {
    format = "${mkSep}${mkSegment "$symbol$state( \\($name\\))" fg_blue}";
    symbol = " ";
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
}
