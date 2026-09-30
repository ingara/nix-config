{ pkgs, ... }:

let
  sessionPath = [ "$HOME/go/bin" ];
in
{
  # The locked HM Go module manages a persistent env file even without configured
  # values; direct package/PATH ownership preserves user-managed `go env -w` state.
  home.packages = [ pkgs.go ];

  home.sessionPath = sessionPath;

  myOptions.developerEnvironmentParity = {
    packages.go = {
      package = pkgs.go;
      commands = [
        "go"
        "gofmt"
      ];
    };
    surfaces.cliGo = { inherit sessionPath; };
  };
}
