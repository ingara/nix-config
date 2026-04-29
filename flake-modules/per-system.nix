# perSystem outputs (devShells, formatter, checks) for the public flake
# when it's evaluated standalone. The lib helpers that both flakes share
# (e.g. `flake.lib.devShellBase`) live in `./lib.nix` so they're available
# via flakeModules.default to the private root flake too.
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
    in
    {
      devShells.default = pkgs.mkShell {
        buildInputs = self.lib.devShellBase pkgs;

        shellHook = ''
          echo "🚀 Nix config development environment loaded!"
          just
        '';
      };

      # `nix fmt` entry point — runs treefmt with all formatters + linters.
      formatter = treefmtEval.config.build.wrapper;

      # `nix flake check` validates formatting.
      checks.formatting = treefmtEval.config.build.check self;
    };
}
