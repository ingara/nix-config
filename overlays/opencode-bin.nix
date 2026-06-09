# opencode — prebuilt binary from opencode's published npm subpackages.
#
# opencode publishes per-arch packages (`opencode-darwin-arm64`,
# `opencode-linux-x64`, etc.) each containing a single Bun-compiled native
# binary. We fetch the right one for the host platform, install it as
# `$out/bin/opencode`, and wrap to set `OPENCODE_BIN_PATH` so any internal
# self-reference resolves to the same store path. The stub `opencode-ai`
# package is just a Node-side launcher that finds the platform binary at
# runtime — we don't need it because we point at the binary directly.
#
# Why this exists: opencode's upstream `nix/opencode.nix` builds from
# source with Bun, and upstream's required Bun version frequently outruns
# nixpkgs' Bun (see opencode 1.15.x requiring bun ^1.3.14 while nixpkgs
# shipped 1.3.13). This overlay sidesteps that race entirely.
#
# Update flow: `just update-opencode-bin` (runs
# `scripts/update-opencode-bin.py`) rewrites `./opencode-bin.json` with the
# latest version and per-arch SHA256s in SRI form.
_final: prev:

let
  inherit (prev) lib;
  lock = lib.importJSON ./opencode-bin.json;

  archForSystem = {
    "x86_64-linux" = "linux-x64";
    "aarch64-linux" = "linux-arm64";
    "x86_64-darwin" = "darwin-x64";
    "aarch64-darwin" = "darwin-arm64";
  };

  system = prev.stdenv.hostPlatform.system;
  arch =
    archForSystem.${system}
      or (throw "opencode-bin: unsupported system ${system} (expected one of ${lib.concatStringsSep ", " (lib.attrNames archForSystem)})");

  platformPackage = "opencode-${arch}";
  hash =
    lock.hashes.${platformPackage}
      or (throw "opencode-bin: opencode-bin.json missing hash for ${platformPackage} (run `just update-opencode-bin`)");
in
{
  opencode-bin = prev.stdenv.mkDerivation {
    pname = "opencode-bin";
    inherit (lock) version;

    src = prev.fetchurl {
      url = "https://registry.npmjs.org/${platformPackage}/-/${platformPackage}-${lock.version}.tgz";
      inherit hash;
    };

    # autoPatchelfHook on Linux only — opencode's binary is Bun-compiled and
    # mostly self-contained, but it dlopens libstdc++ etc. and needs the
    # nixpkgs store paths rather than /usr/lib.
    nativeBuildInputs = [
      prev.makeWrapper
    ]
    ++ lib.optionals prev.stdenv.isLinux [ prev.autoPatchelfHook ];

    buildInputs = lib.optionals prev.stdenv.isLinux [
      prev.stdenv.cc.cc.lib
    ];

    # The tarball is `package/{package.json,bin/opencode}` — no build, just
    # extract and link.
    installPhase = ''
      runHook preInstall
      install -Dm755 bin/opencode "$out/libexec/opencode/opencode"
      makeWrapper "$out/libexec/opencode/opencode" "$out/bin/opencode" \
        --set OPENCODE_BIN_PATH "$out/libexec/opencode/opencode"
      runHook postInstall
    '';

    meta = {
      description = "AI coding agent for the terminal (prebuilt npm binary)";
      homepage = "https://github.com/sst/opencode";
      license = lib.licenses.mit;
      mainProgram = "opencode";
      platforms = lib.attrNames archForSystem;
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  };
}
