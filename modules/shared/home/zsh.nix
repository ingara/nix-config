# Zsh shell configuration.
#
# Shared aliases live in `./aliases.nix` (also consumed by `./fish.nix`).
# initContent adds the `n` nvim helper and `zi` zoxide interactive mode.
{
  config,
  ...
}:

{
  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
    autocd = false;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    cdpath = [ "~/.local/share/src" ];
    shellAliases = import ./aliases.nix { };
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
    initContent = ''
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
}
