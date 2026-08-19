# codexbar-cli — AI coding-provider usage limits, on the command line.
#
# Deliberately not nixpkgs' `codexbar`, which packages the macOS menu bar app
# and wraps `CodexBar.app/Contents/MacOS/CodexBar` — the GUI binary — as
# `bin/codexbar`. The command-line tool is a different executable beside it
# (`Contents/Helpers/CodexBarCLI`) with no wrapper of its own, so `codexbar
# usage --format json` off that package launches an app instead of printing
# JSON. Upstream ships the CLI as its own tarball, which costs ~35M instead of
# ~140M, covers both platforms in one derivation, and leaves `pkgs.codexbar`
# alone for anyone who wants the app.
#
# Bump procedure: set `version`, then re-prefetch every hash in `assets`.
_final: prev:
let
  version = "0.47.0";

  # Keyed by system, carrying each asset's own arch spelling — `aarch64` here,
  # which is neither `linuxArch` ("arm64") nor a value worth deriving.
  #
  # Linux takes the static musl builds over the smaller glibc ones: those carry
  # an ELF interpreter and would need autoPatchelfHook, whose result no darwin
  # workstation can check without a linux builder. A static binary has nothing
  # to resolve.
  assets = {
    aarch64-darwin = {
      suffix = "macos-arm64";
      hash = "sha256-0smUipjYcNzCt6ceH2zrwgg99zXJUl9fefbsmSsGyxI=";
    };
    x86_64-darwin = {
      suffix = "macos-x86_64";
      hash = "sha256-8H7EH0uAMQCm9kwEd8PyLuumDf2RRjDW2mchF7ToFYI=";
    };
    x86_64-linux = {
      suffix = "linux-musl-x86_64";
      hash = "sha256-EHVc2hDkH23MHNs5MBZLyRKiZREeA/i5+14+cE47qEY=";
    };
    aarch64-linux = {
      suffix = "linux-musl-aarch64";
      hash = "sha256-3ncd2L7DqwEB7v0aEo0o4gcbb5sgwROVwO7EvjR3o78=";
    };
  };

  inherit (prev.stdenv.hostPlatform) system;

  asset = assets.${system} or (throw "codexbar-cli: no release tarball for ${system}");
in
{
  codexbar-cli = prev.stdenvNoCC.mkDerivation {
    pname = "codexbar-cli";
    inherit version;

    src = prev.fetchurl {
      url = "https://github.com/steipete/CodexBar/releases/download/v${version}/CodexBarCLI-v${version}-${asset.suffix}.tar.gz";
      inherit (asset) hash;
    };

    # Flat tarball: the binary, a `codexbar` symlink beside it, and VERSION.
    sourceRoot = ".";

    dontConfigure = true;
    dontBuild = true;
    # The darwin binary is ad-hoc signed; stripping it breaks that signature.
    dontStrip = true;

    # VERSION ships beside the binary because the standalone CLI reads its
    # version from that sidecar rather than an app bundle's Info.plist —
    # without it `codexbar --version` degrades to a bare "CodexBar". The lookup
    # is relative to the executable, so it has to land in bin/, where buildEnv
    # also links it and a profile symlink still resolves it.
    installPhase = ''
      runHook preInstall
      install -Dm755 CodexBarCLI "$out/bin/codexbar"
      install -Dm444 VERSION "$out/bin/VERSION"
      runHook postInstall
    '';

    nativeInstallCheckInputs = [ prev.versionCheckHook ];
    doInstallCheck = true;
    versionCheckProgramArg = "--version";

    meta = {
      description = "Command-line usage stats for AI coding-provider limits";
      homepage = "https://codex.bar/";
      license = prev.lib.licenses.mit;
      sourceProvenance = [ prev.lib.sourceTypes.binaryNativeCode ];
      mainProgram = "codexbar";
      platforms = prev.lib.attrNames assets;
    };
  };
}
