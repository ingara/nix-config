# REMOVE WHEN llm-agents packages stable OpenCode >= 2.3.2 as `opencode` with these platform fixes.
# Upstream: https://github.com/numtide/llm-agents.nix/blob/0538a7598ce7eb1f80619bb93f613ed664d33510/packages/opencode2/package.nix
# Verify: `just eval <host>`, `just build`, then the selected package's `opencode --version`.
{
  stdenv,
  fetchurl,
  upstream,
}:
let
  version = "2.3.2";
  platform =
    {
      aarch64-linux = {
        name = "linux-arm64";
        hash = "sha512-t44ZuW5CKaWiRSp4gWUDurMf4edyXw/SmUty1pRi827zda0T2RatKWj4LnMUewNCL05COLB1Ppg8RWicswhFaQ==";
      };
      aarch64-darwin = {
        name = "darwin-arm64";
        hash = "sha512-cYrIzW8CvYc52INFA/cXmw7U2mk+JNWaV+olH7AflYqa/5srSrA/hbLwF7G1N4QTRMtOFrmeTM0LVN81q396sg==";
      };
      x86_64-linux = {
        name = "linux-x64";
        hash = "sha512-E9txUc4fNtvuEQUiEx84h4/bd/LJZcAHdIu0yfZRP8KDVP79WhzhEd7BTckJUyvWUc58ZP/o+nfgcnTQnvfJgw==";
      };
    }
    .${stdenv.hostPlatform.system};
in
upstream.overrideAttrs (old: {
  pname = "opencode";
  inherit version;
  src = fetchurl {
    url = "https://registry.npmjs.org/@opencode/cli-${platform.name}/-/cli-${platform.name}-${version}.tgz";
    inherit (platform) hash;
  };

  # Keep the hidden ELF and its upstream postFixup target; rename only the public wrapper.
  postInstall = (old.postInstall or "") + ''
    mv "$out/bin/opencode2" "$out/bin/opencode"
  '';
  passthru = builtins.removeAttrs old.passthru [
    "updater"
    "updateScript"
  ];
  meta = old.meta // {
    mainProgram = "opencode";
    changelog = "https://github.com/anomalyco/opencode/releases/tag/v${version}";
  };
})
