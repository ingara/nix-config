{
  config,
  lib,
  pkgs,
  ...
}:

# Upstream `nixos-version` bakes system.configurationRevision into a script in
# environment.systemPackages, so every new commit changes system.path and
# restarts units whose restart triggers include it (polkit).
# This replacement keeps the revision out of system.path: the toplevel carries
# it, and the script reads it at runtime from the system it was invoked
# through (<toplevel>/sw/bin/nixos-version, recognised by the toplevel's
# nixos-version file), else /run/current-system.
# Version, codename and Nixpkgs revision change only with Nixpkgs, so they
# stay baked.
#
# The revision is written by system.systemBuilderCommands, an internal option;
# no public option writes a file into the toplevel.
#
# This module owns system.tools.nixos-version.enable and sets it false to drop
# the upstream script. The replacement follows only upstream's default gate,
# so per-host opt-in or opt-out through that option is not preserved.
#
# REMOVE WHEN upstream nixos-version reads its version data at runtime instead
# of embedding it (NixOS/nixpkgs#238557 or a successor).
# Verify: on two commits that differ only in a comment,
# `just eval-attr <host> system.path.drvPath` prints the same path.
let
  inherit (config.system) configurationRevision;
  inherit (config.system.nixos) version codeName revision;

  baseJson = builtins.toJSON (
    {
      nixosVersion = version;
    }
    // lib.optionalAttrs (revision != null) {
      nixpkgsRevision = revision;
    }
  );

  script = pkgs.writeShellApplication {
    name = "nixos-version";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      bin=$(dirname -- "$0")
      sw=$(dirname -- "$bin")
      toplevel=$(dirname -- "$sw")
      if [[ ''${bin##*/} != bin || ''${sw##*/} != sw || ! -f $toplevel/nixos-version ]]; then
        toplevel=/run/current-system
      fi

      revisionFile=$toplevel/configuration-revision

      case "''${1-}" in
        -h|--help)
          exec man nixos-version
          ;;
        --hash|--revision)
          ${
            if revision != null && lib.match "[0-9a-f]+" revision != null then
              "echo ${revision}"
            else
              ''
                echo "$0: Nixpkgs commit hash is unknown" >&2
                exit 1
              ''
          }
          ;;
        --configuration-revision)
          if [[ ! -f $revisionFile ]]; then
            echo "$0: configuration revision is unknown" >&2
            exit 1
          fi
          cat "$revisionFile"
          echo
          ;;
        --json)
          if [[ -f $revisionFile ]]; then
            jq --null-input --compact-output --sort-keys \
              --argjson base ${lib.escapeShellArg baseJson} \
              --rawfile rev "$revisionFile" \
              '$base + { configurationRevision: $rev }'
          else
            jq --null-input --compact-output --sort-keys \
              --argjson base ${lib.escapeShellArg baseJson} '$base'
          fi
          ;;
        *)
          echo ${lib.escapeShellArg "${version} (${codeName})"}
          ;;
      esac
    '';
  };

  nixos-version =
    pkgs.runCommand "nixos-version" { nativeBuildInputs = [ pkgs.installShellFiles ]; }
      ''
        install -Dm755 ${lib.getExe script} $out/bin/nixos-version
        installManPage ${pkgs.path + "/nixos/modules/installer/tools/manpages/nixos-version.8"}
      '';
in
{
  system.tools.nixos-version.enable = false;

  environment.systemPackages = lib.mkIf (config.nix.enable && !config.system.disableInstallerTools) [
    nixos-version
  ];

  system.systemBuilderCommands = lib.optionalString (configurationRevision != null) ''
    printf '%s' ${lib.escapeShellArg configurationRevision} > $out/configuration-revision
  '';
}
