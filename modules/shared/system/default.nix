{ inputs, ... }:

{
  imports = [
    ./ai/agent-git.nix
    ./ai/claude-code.nix
    ./ai/codex.nix
    ../nixpkgs.nix
  ];

  # So each host can report which commit it's running, read with
  # `<platform>-version --configuration-revision`. Drives `just fleet-status`.
  system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

  environment = {
    variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };
}
