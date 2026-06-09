_:

{
  imports = [
    ./ai/claude-code.nix
    ../nixpkgs.nix
  ];

  environment = {
    variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      XDG_CONFIG_HOME = "$HOME/.config";
    };
  };
}
