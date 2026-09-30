{ lib }:

{
  bearerTokenPaths = server: lib.filter (path: path != null) (lib.attrValues server.bearerTokenFiles);

  hasBearerToken = server: lib.any (path: path != null) (lib.attrValues server.bearerTokenFiles);

  selectedBearerTokenFile = identity: server: server.bearerTokenFiles.${identity};

  tokenEnvVar = name: "MCP_BEARER_TOKEN_${lib.toUpper (builtins.hashString "sha256" name)}";

  # Credential references differ per identity by design; parity compares
  # which servers authenticate, not where each identity's credential lives.
  maskAuthorization = lib.mapAttrs (
    _: server:
    server
    // lib.optionalAttrs (server ? headers.Authorization) {
      headers = server.headers // {
        Authorization = "<identity bearer credential>";
      };
    }
  );
}
