# perSystem outputs (devShells, formatter, checks) for the public flake
# when it's evaluated standalone.
{
  inputs,
  self,
  ...
}:
{
  perSystem =
    {
      pkgs,
      ...
    }:
    let
      treefmtEval = inputs.treefmt-nix.lib.evalModule pkgs ../treefmt.nix;
      agent-github-router = pkgs.callPackage ../packages/agent-github-router { };
    in
    {
      devShells.default = pkgs.mkShell {
        buildInputs = self.lib.devShellBase pkgs;

        shellHook = ''
          echo "🚀 Nix config development environment loaded!"
        '';
      };

      # `nix fmt` entry point.
      formatter = treefmtEval.config.build.wrapper;

      checks.formatting = treefmtEval.config.build.check self;
      checks.agent-github-router = agent-github-router;

      packages.agent-github-router = agent-github-router;
      packages.lavish-axi = pkgs.callPackage ../overlays/lavish-axi/package.nix {
        src = inputs.lavish-axi;
      };
    };
}
