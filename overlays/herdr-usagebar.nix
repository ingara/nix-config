# herdr-agent-usage: per-pane context meters and provider plan windows in
# herdr's sidebar.
#
# An overlay rather than a `let` binding in home/ai/herdr-plugins.nix, where its
# three sibling plugins live. Claude Code only exposes rate limits through its
# `statusLine`, and that is configured from a *system*-scope module — which
# cannot read home-manager config to find an HM-module-local binding. Overlays
# are loaded into both package sets (see shared/nixpkgs.nix), so this is the one
# mechanism that reaches both. The siblings need no such reach and stay put.
#
# Not a workaround pin, so there is no REMOVE WHEN: the patches below exist
# because the plugin's scripts assume an FHS layout, which will not change.
final: _prev: {
  herdr-usagebar = final.buildGoModule (finalAttrs: {
    pname = "herdr-usagebar";
    version = "0.5.5";

    src = final.fetchFromGitHub {
      owner = "senna-lang";
      repo = "herdr-agent-usage";
      tag = "v${finalAttrs.version}";
      hash = "sha256-/gOG/LPEGC6PEOn7N29hBkwxAqOyNtu5RhAQUz/jzGA=";
    };

    vendorHash = "sha256-rIJlQO/NKzOKbt4NL05fHzRTjReoGcbv4i4bwtNNc5w=";
    subPackages = [ "cmd/usagebar" ];

    postInstall = ''
      cp herdr-plugin.toml "$out/herdr-plugin.toml"
      install -Dm755 bin/*.sh -t "$out/bin/"

      # These scripts exec each other directly rather than going through the
      # manifest, so their own `#!/bin/bash` shebangs decide whether they
      # run — and NixOS's /bin holds only `sh`. Absolutising the manifest's
      # interpreter is not enough: every event died on the second hop, which
      # left the sidebar's `$` tokens permanently empty. The plugin is
      # therefore unusable on NixOS however it is installed, not just from
      # the store.
      #
      # Substituted explicitly rather than left to patchShebangs, which
      # resolves whatever bash sits on the build PATH — it cannot express
      # "this variant", and the interactive build drags in readline and
      # ncurses for scripts that only need an interpreter.
      substituteInPlace "$out/bin"/*.sh \
        --replace-quiet '#!/bin/bash' '#!${final.lib.getExe final.bashNonInteractive}'

      if ${final.gnugrep}/bin/grep -l '^#!/bin/' "$out/bin"/*.sh >/dev/null 2>&1; then
        echo "usagebar: a /bin/ shebang survived patching:" >&2
        ${final.gnugrep}/bin/grep -l '^#!/bin/' "$out/bin"/*.sh >&2
        exit 1
      fi

      # `--all`. Without it the panel lists only providers that currently have an
      # open agent pane, so a session of Claude panes shows an empty board even
      # when another provider has a live window worth seeing.
      substituteInPlace "$out/herdr-plugin.toml" \
        --replace-fail '"bin/run-limits-pane.sh"]' '"bin/run-limits-pane.sh", "--all"]'

      substituteInPlace "$out/herdr-plugin.toml" \
        --replace-fail '"bash"' '"${final.lib.getExe final.bashNonInteractive}"'
    '';

    meta = {
      description = "Context meters and provider rate limits for agents running in herdr";
      homepage = "https://github.com/senna-lang/herdr-agent-usage";
      license = final.lib.licenses.mit;
      mainProgram = "usagebar";
      platforms = final.lib.platforms.unix;
    };
  });
}
