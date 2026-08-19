# claude-statusline-render — the status line Claude Code draws above its input.
#
# An overlay rather than a Home Manager module because Claude Code's
# `statusLine` is configured from *system*-scope managed settings, which cannot
# read HM config to find an HM-local binding. Overlays are loaded into both
# package sets (see modules/shared/nixpkgs.nix), so this is the one mechanism
# that reaches the scope that needs it. The palette still has to come from
# Stylix, which is HM-scope, so it arrives out-of-band: modules/shared/home/ai/
# claude-statusline.nix writes the base16 slots to a file under XDG_CONFIG_HOME
# that claude-statusline.sh reads, and the built-in defaults cover hosts
# without it.
#
# A deliberate deviation from scripts/AGENTS.md, which reserves bash for glue
# under ~50 lines: claude-statusline.sh is ~250. It buys per-turn startup
# (measured here: bash+jq 4.4ms, python3+stdlib 17.5ms) and build-time
# shellcheck via writeShellApplication. Only the 13ms is a hot-path argument,
# and it is small — revisit the lane if this grows another parser.
#
# claude-statusline.sh and install.md are mirrored verbatim to a public gist
# (https://gist.github.com/ingara/2e5e9c041351700c713093e96205b9cb) for people
# outside this repo, which is why the script carries its own `set -o` prologue
# and portability notes rather than leaning on writeShellApplication's, and
# why it must never mention Nix or this repo. A commit touching either file
# leaves that copy stale: ask the operator whether to refresh, then run
# `just publish-statusline-gist` — it mirrors from committed HEAD only and
# verifies the result. Never push to the gist by any other route or as a side
# effect of another change.
_final: prev: {
  claude-statusline-render = prev.writeShellApplication {
    name = "claude-statusline-render";

    # git is the only datum the payload does not carry (branch + working-tree
    # status); everything else is a field Claude Code hands us on stdin.
    # Pinned rather than taken from PATH because this runs in Claude Code's exec
    # environment, not a login shell.
    #
    # `git`, not `gitMinimal`, despite the ~384 MiB that shows up in this
    # package's standalone closure: any host rendering a status line already has
    # full git, so the marginal cost is zero — while gitMinimal is a second,
    # otherwise-absent 159 MiB git. Measure the delta against the host closure,
    # not this derivation's.
    runtimeInputs = [
      prev.jq
      prev.git
    ];

    text = builtins.readFile ./claude-statusline.sh;
  };
}
