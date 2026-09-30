{ config, lib, ... }:

let
  mcpAuth = import ../../_mcp-auth.nix { inherit lib; };
  enabledServers = lib.filterAttrs (_: server: server.enabled) config.myOptions.mcp.servers;
  identity = config.myOptions.executionIdentity;
  unauthenticatedServers = lib.filterAttrs (_: server: !mcpAuth.hasBearerToken server) enabledServers;
  authenticatedServers = lib.filterAttrs (
    _: server: mcpAuth.hasBearerToken server && mcpAuth.selectedBearerTokenFile identity server != null
  ) enabledServers;
  claudeMcpServers = lib.mapAttrs (
    name: server:
    let
      tokenEnvVar = mcpAuth.tokenEnvVar name;
    in
    {
      type = "http";
      inherit (server) url;
      headers.Authorization = "Bearer " + "\${" + tokenEnvVar + "}";
    }
  ) authenticatedServers;
  opencodeMcpServers = lib.mapAttrs (_: server: {
    type = "remote";
    inherit (server) url;
    oauth = false;
    headers.Authorization = "Bearer {file:${mcpAuth.selectedBearerTokenFile identity server}}";
  }) authenticatedServers;
in
{
  programs = {
    mcp = {
      enable = true;
      servers = lib.mapAttrs (_: server: { inherit (server) url; }) unauthenticatedServers;
    };

    claude-code = {
      enable = true;
      package = null;
      configDir = "${config.xdg.configHome}/claude";
      enableMcpIntegration = true;
      mcpServers = claudeMcpServers;
    };

    opencode.settings.mcp = opencodeMcpServers;
  };

  myOptions.developerEnvironmentParity.surfaces.mcp = {
    inherit identity;
    shared = unauthenticatedServers;
    claude = claudeMcpServers;
    opencode = mcpAuth.maskAuthorization opencodeMcpServers;
  };
}
