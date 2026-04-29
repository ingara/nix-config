# Small, mostly-default CLI tools bundled into one file because each
# enables in a handful of lines and they don't warrant separate modules.
#
# Contents:
#   - `programs.bat`      — cat with syntax highlighting
#   - `programs.fzf`      — fuzzy finder; fish + zsh integration on
#   - `programs.ripgrep`  — rg with column/line-number/color tweaks
#   - `programs.zoxide`   — `z` smarter cd; fish + zsh integration on
#   - `programs.direnv`   — auto-envrc; nix-direnv backend
#   - `programs.mise`     — runtime version manager; fish + zsh integration on
#
# Split a tool back out into its own file once its config grows past
# ~30 LOC or gains non-trivial conditionals.
_:

{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.bat = {
    enable = true;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
  };

  programs.ripgrep = {
    enable = true;
    arguments = [
      "--column"
      "--line-number"
      "--max-columns-preview"
      "--colors=line:style:bold"
    ];
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
  };

  programs.mise = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
  };
}
