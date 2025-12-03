# Enhanced starship configuration with bracketed segments
# Inspired by starship bracketed presets and powerlevel10k classic style
{ lib }:
{
  # Add blank line before prompt for breathing room
  add_newline = true;

  # Left side: line connector, directory, git info
  # Right side: cmd_duration, language versions, time
  format = lib.concatStrings [
    "$username"
    "$hostname"
    "[╭─](bold green)"
    "$directory"
    "$git_branch"
    "$git_status"
    "$fill"
    "$cmd_duration"
    "$nodejs"
    "$rust"
    "$python"
    "$nix_shell"
    "$time"
    "$line_break"
    "[╰─](bold green)$character"
  ];

  # Fill space between left and right
  fill = {
    symbol = " ";
  };

  # Bracketed directory with custom colors
  directory = {
    truncation_length = 5;
    truncation_symbol = "…/";
    truncate_to_repo = false;
    format = "[ $path ]($style)";
    style = "bold cyan";
    substitutions = {
      "Documents" = " ";
      "Downloads" = " ";
      "Music" = " ";
      "Pictures" = " ";
    };
  };

  # Git branch with bracket
  git_branch = {
    format = "[ $symbol$branch(:$remote_branch) ]($style)";
    symbol = " ";
    style = "bold purple";
  };

  # Git status with counts
  git_status = {
    format = "([\\[$all_status$ahead_behind\\]]($style) )";
    style = "bold red";
    conflicted = "🏳";
    ahead = "⇡\${count}";
    behind = "⇣\${count}";
    diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
    up_to_date = "✓";
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
    format = "[ $duration ]($style)";
    style = "bold yellow";
  };

  # Node.js version (right side, bracketed)
  nodejs = {
    format = "[ $symbol($version) ]($style)";
    symbol = " ";
    style = "bold green";
    detect_files = [
      "package.json"
      ".node-version"
      ".nvmrc"
    ];
  };

  # Rust version (right side, bracketed)
  rust = {
    format = "[ $symbol($version) ]($style)";
    symbol = " ";
    style = "bold red";
  };

  # Python version (right side, bracketed)
  python = {
    format = "[ $symbol$pyenv_prefix($version) ]($style)";
    symbol = " ";
    style = "bold yellow";
  };

  # Nix shell indicator (right side, bracketed)
  nix_shell = {
    format = "[ $symbol$state( \\($name\\)) ]($style)";
    symbol = " ";
    style = "bold blue";
  };

  # Time (right side, bracketed)
  time = {
    disabled = false;
    format = "[ $time ]($style)";
    style = "bold white";
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
