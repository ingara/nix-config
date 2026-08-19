# showy-quota — always-on AI plan quota strips, driven by the codexbar CLI.
#
# Not in nixpkgs. Built from source rather than the release tarball so the
# renderer is compiled for the host instead of trusting a prebuilt blob.
#
# The output deliberately keeps upstream's *repo* layout — `bin/`, `lib/`,
# `share/`, `adapters/` all directly under $out — because every entry point
# locates its siblings by walking up from its own `BASH_SOURCE[0]`: the bin/
# scripts go up one level, the sketchybar adapters up three. Flattening any of
# it into a conventional prefix silently breaks that resolution. The walk
# follows symlink chains to the real file first, so linking an adapter into
# ~/.config/sketchybar still resolves back here.
_final: prev:
let
  runtimeDeps = [
    # jq does all the JSON reduction; curl probes `codexbar serve`;
    # imagemagick tints the per-provider icons; python3 backs the icon cache.
    prev.jq
    prev.curl
    prev.imagemagick
    prev.python3
  ]
  # The plugin shells out to `sketchybar` on every render. Same package the
  # launchd agent runs, so this adds no second copy to the closure.
  ++ prev.lib.optional prev.stdenv.hostPlatform.isDarwin prev.sketchybar;
in
{
  showy-quota = prev.rustPlatform.buildRustPackage (finalAttrs: {
    pname = "showy-quota";
    version = "0.7.0";

    src = prev.fetchFromGitHub {
      owner = "enieuwy";
      repo = "showy-quota";
      tag = "v${finalAttrs.version}";
      hash = "sha256-JSY3WUgYkYvfrYH2fUDd74Hk5GHS8h3kO0wHCAi+UA0=";
    };

    cargoHash = "sha256-3jf2Pn/PHfQuqDl5SK/s7ZrQ0pbixENrL6M8UfA+ul4=";

    # Only the renderer. The sibling crate is the zellij WASM plugin, which
    # cannot build for the host target at all.
    cargoBuildFlags = [
      "--package"
      "showy-quota-zellij-core"
      "--bin"
      "showy-quota-render"
    ];
    # Whole crate, not just the bin target: narrowing tests to `--bin` the way
    # the build flags do would skip the lib unit tests and the render_cli
    # integration suite, which are the ones worth running.
    cargoTestFlags = [
      "--package"
      "showy-quota-zellij-core"
    ];

    nativeBuildInputs = [ prev.makeWrapper ];

    postInstall = ''
      cp -r bin lib share adapters "$out/"
      chmod -R u+w "$out/bin" "$out/adapters"

      patchShebangs "$out/bin" "$out/adapters"

      # coreutils stays off this PATH. Upstream probes for GNU `gdate` before
      # falling back to BSD `date -j -f` (likewise `stat -f` then `stat -c`),
      # so prepending it on darwin would shadow the BSD tools the fallback
      # needs without supplying the `gdate` name the GNU branch wants —
      # breaking both paths at once.
      for script in "$out"/bin/showy-quota* "$out"/adapters/sketchybar/plugins/*.sh; do
        [ -f "$script" ] || continue
        wrapProgram "$script" --prefix PATH : ${prev.lib.makeBinPath runtimeDeps}
      done
    '';

    # The bin/ scripts resolve the renderer as a sibling in their own
    # directory before falling back to PATH. wrapProgram moves each script to
    # a dotfile beside itself, so that lookup still lands in $out/bin — assert
    # it rather than discover a silently renderer-less bar later.
    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck
      test -x "$out/bin/showy-quota-render"
      test -x "$out/adapters/sketchybar/plugins/showy_quota.sh"
      test -f "$out/lib/common.sh"
      "$out/bin/showy-quota-render" --help > /dev/null
      runHook postInstallCheck
    '';

    meta = {
      description = "Always-on AI plan quota strips for SketchyBar, Zellij, and tmux";
      homepage = "https://github.com/enieuwy/showy-quota";
      license = prev.lib.licenses.mit;
      mainProgram = "showy-quota";
      platforms = prev.lib.platforms.unix;
    };
  });
}
