{ lib, pkgs }:

let
  capabilities = {
    corepack = {
      package = pkgs.corepack_24;
      commands = [ "corepack" ];
    };
    fd = {
      package = pkgs.fd;
      commands = [ "fd" ];
    };
    jq = {
      package = pkgs.jq;
      commands = [ "jq" ];
    };
    just = {
      package = pkgs.just;
      commands = [ "just" ];
    };
    nixfmt = {
      package = pkgs.nixfmt;
      commands = [ "nixfmt" ];
    };
    node = {
      package = pkgs.nodejs_24;
      commands = [
        "node"
        "npm"
        "npx"
      ];
    };
    python = {
      package = pkgs.python3;
      commands = [
        "python"
        "python3"
      ];
    };
    statix = {
      package = pkgs.statix;
      commands = [ "statix" ];
    };
    uv = {
      package = pkgs.uv;
      commands = [
        "uv"
        "uvx"
      ];
    };
    xh = {
      package = pkgs.xh;
      commands = [ "xh" ];
    };
  };
in
{
  inherit capabilities;
  packages = lib.mapAttrsToList (_: capability: capability.package) capabilities;
}
