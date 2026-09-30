{
  lib,
  stdenvNoCC,
  nodejs_22,
  pnpm_11,
  pnpmConfigHook,
  fetchPnpmDeps,
  makeWrapper,
  src,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "lavish-axi";
  inherit ((lib.importJSON (src + "/package.json"))) version;
  inherit src;

  # A registered SDK handler intercepts self-update before any registry lookup.
  patches = [ ./disable-self-update.patch ];

  nativeBuildInputs = [
    nodejs_22
    pnpm_11
    pnpmConfigHook
    makeWrapper
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs)
      pname
      version
      src
      prePnpmInstall
      ;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-Ag2s1xr0P2egphjqJKG02UbHlKVwA3A1tDMOjD8KnlE=";
  };

  # REMOVE WHEN these locked releases are replaced; retry without the exceptions.
  # https://pnpm.io/settings#trustpolicyexclude documents historical provenance loss.
  prePnpmInstall = ''
    cat >> pnpm-workspace.yaml <<'YAML'
    trustPolicyExclude:
      - chokidar@4.0.3
      - langium@3.3.1
    YAML
  '';

  # The CLI also generates skill instructions; keep those on the store executable.
  postPatch = ''
    substituteInPlace src/skill.js --replace-fail 'npx -y lavish-axi' 'lavish-axi'
    sed -i '/^You do not need lavish-axi installed globally /c\Use the declaratively installed lavish-axi executable.' src/skill.js
    sed -i '/^If lavish-axi output shows a follow-up command starting /d' src/skill.js
  '';

  buildPhase = ''
    runHook preBuild
    # REMOVE WHEN Excalidraw supports disabling its CDN font fallback.
    # https://unpkg.com/@excalidraw/excalidraw@0.18.1/dist/prod/chunk-K2UTITRG.js
    substituteInPlace node_modules/@excalidraw/excalidraw/dist/prod/chunk-K2UTITRG.js \
      --replace-fail 'return r.push(new URL(n,jn.ASSETS_FALLBACK_URL)),r' 'return r'
    node scripts/build.js
    # REMOVE WHEN upstream vendors Xiaolai; the install check verifies its presence.
    # https://github.com/kunchenguid/lavish-axi/blob/78929b760996966d89f8796c731c8cf331647177/scripts/build.js
    cp -r node_modules/@excalidraw/excalidraw/dist/prod/fonts/Xiaolai dist/whiteboard/fonts/
    node scripts/build-skill.js
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    # Browser dependencies are bundled in dist; only the external Node imports remain.
    CI=true pnpm install --offline --frozen-lockfile --ignore-scripts --prod
    mkdir -p "$out/lib/lavish-axi" "$out/bin"
    cp -r dist node_modules package.json LICENSE THIRD-PARTY-NOTICES.md skills "$out/lib/lavish-axi/"
    makeWrapper ${lib.getExe nodejs_22} "$out/bin/lavish-axi" \
      --add-flags "$out/lib/lavish-axi/dist/cli.mjs"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export LAVISH_AXI_TELEMETRY=off
    "$out/bin/lavish-axi" --help > help.txt
    "$out/bin/lavish-axi" design > design.txt
    "$out/bin/lavish-axi" playbook > playbooks.txt
    for flag in --check --dry-run --help; do
      if "$out/bin/lavish-axi" update "$flag" > update.txt; then
        echo "Self-update unexpectedly succeeded" >&2
        exit 1
      fi
      grep -q 'Self-update is disabled' update.txt
    done
    ! grep -E 'npx|npm install' help.txt design.txt playbooks.txt
    test -s "$out/lib/lavish-axi/dist/chrome-client.js"
    test -s "$out/lib/lavish-axi/dist/chrome.css"
    test -s "$out/lib/lavish-axi/dist/design/tailwindcss-browser.js"
    test -s "$out/lib/lavish-axi/dist/whiteboard/whiteboard.js"
    test -d "$out/lib/lavish-axi/dist/whiteboard/fonts/Excalifont"
    test -d "$out/lib/lavish-axi/dist/whiteboard/fonts/Xiaolai"
    runHook postInstallCheck
  '';

  meta = {
    description = "Local browser review and annotation of HTML artifacts";
    homepage = "https://github.com/kunchenguid/lavish-axi";
    license = lib.licenses.mit;
    mainProgram = "lavish-axi";
    platforms = lib.platforms.unix;
  };
})
