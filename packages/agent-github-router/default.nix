{
  buildGoModule,
  lib,
}:

buildGoModule {
  pname = "agent-github-router";
  version = "0.1.0";
  src = ./.;
  vendorHash = null;

  meta = {
    description = "Fail-closed GitHub credential router for automation";
    license = lib.licenses.mit;
    mainProgram = "agent-github-router";
    platforms = lib.platforms.unix;
  };
}
