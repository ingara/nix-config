# Credential-free Fish UX shared by operator and standalone HM profiles.
{ lib, pkgs, ... }:

let
  aliases = import ./cli-ux-aliases.nix { inherit pkgs; };
  shellInit = ''
    set -g fish_greeting

    ${lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
      # macOS Alt+D fzf
      bind "∂" fzf-cd-widget

      # Shift+Enter for newline (kitty keyboard protocol: \e[13;2u)
      bind \e\[13\;2u 'commandline -i \n'
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
    zi = ''
      set -l result (zoxide query -l | fzf --height 40% --reverse --preview 'eza -la {}')
      and cd $result
    '';
    # Runs after plugin bindings and neutralises fzf's Alt+C binding. On
    # macOS, Cmd+C without a selection can fall through as Meta+C.
    fish_user_key_bindings = ''
      bind --erase \ec 2>/dev/null
      bind --erase --mode insert \ec 2>/dev/null
    '';
  };
in
{
  programs.fish = {
    enable = true;
    shellAliases = aliases;
    inherit shellInit functions;
  };

  myOptions.developerEnvironmentParity = {
    inherit aliases;
    surfaces.cliUx.fish = {
      enable = true;
      inherit shellInit functions;
      darwinBindings = pkgs.stdenv.hostPlatform.isDarwin;
    };
  };
}
