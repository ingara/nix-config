# Tmux multiplexer configuration.
#
# Plugins cover pane navigation, sidebar, fzf, battery, URL finder. The
# vim-tmux-navigator binding detects nested vim processes so C-hjkl
# transparently selects panes or moves cursor inside vim.
#
# Discovery: every custom bind carries a `-N "..."` description, surfaced
# via two fzf popups — `prefix + ?` lists the prefix table, `M-?` lists
# the root (unprefixed) table. The popup invokes the bound action via
# `tmux send-keys`, so selection behaves identically to pressing the key.
# See `dotfiles/scripts/tmux-keys-popup.sh`.
#
# Status-bar layout is rendered here from `config.lib.stylix.colors`
# (same pattern as `sketchybar.nix` / `nvim-theme.nix`) so the bar
# follows `myOptions.theme.scheme` without per-theme plugins. The bundled
# `stylix.targets.tmux` is still enabled per-platform; its default
# `status-style` etc. are overridden by the explicit `set -g` calls
# below. We roll our own mode chip via `client_prefix` / `pane_in_mode`
# instead of using tmux-prefix-highlight, because we want a chip visible
# in NORMAL mode too.
{
  pkgs,
  lib,
  config,
  ...
}:

let
  c = config.lib.stylix.colors.withHashtag;
  hasGui = config.myOptions.hasGui;

  # -------------------------------------------------------------------------
  # Hex color blender — used for the clock-box subtle mode tint.
  # No stylix helper for this; ~20 LOC of pure Nix is the cheaper alternative
  # to a separate runtime tool or hardcoded per-theme color tables.
  # -------------------------------------------------------------------------
  hexChars = "0123456789abcdef";
  hexCharToInt =
    ch:
    let
      m = builtins.match "[0-9a-fA-F]" ch;
      lo = lib.toLower ch;
    in
    if m == null then
      throw "tmux.nix: hexCharToInt got non-hex char ${ch}"
    else
      lib.lists.findFirstIndex (x: x == lo) null (lib.stringToCharacters hexChars);
  hexByteToInt =
    s: 16 * (hexCharToInt (builtins.substring 0 1 s)) + hexCharToInt (builtins.substring 1 1 s);
  intToHexByte =
    n:
    let
      hi = n / 16;
      lo = n - hi * 16;
    in
    builtins.substring hi 1 hexChars + builtins.substring lo 1 hexChars;
  parseHex =
    h:
    let
      s = lib.removePrefix "#" h;
    in
    {
      r = hexByteToInt (builtins.substring 0 2 s);
      g = hexByteToInt (builtins.substring 2 2 s);
      b = hexByteToInt (builtins.substring 4 2 s);
    };
  # Mix two `#rrggbb` colors; `ratio` is how much of `b` to blend into `a`.
  mixHex =
    aColor: bColor: ratio:
    let
      pa = parseHex aColor;
      pb = parseHex bColor;
      blend =
        ca: cb:
        let
          v = (1.0 - ratio) * (1.0 * ca) + ratio * (1.0 * cb);
        in
        if v < 0.0 then
          0
        else if v > 255.0 then
          255
        else
          builtins.floor v;
    in
    "#"
    + (intToHexByte (blend pa.r pb.r))
    + (intToHexByte (blend pa.g pb.g))
    + (intToHexByte (blend pa.b pb.b));

  # -------------------------------------------------------------------------
  # Pre-computed mode-aware tints (subtle clock-box behaviour from round 3).
  # ~20 % of base09 / base0A blended over the box's base02. Loud enough to
  # notice during prefix/copy, quiet enough to ignore otherwise.
  # -------------------------------------------------------------------------
  clockBgNormal = c.base02;
  clockBgPrefix = mixHex c.base02 c.base09 0.20;
  clockBgCopy = mixHex c.base02 c.base0A 0.20;

  # SSH chip background (round 4 T1: ~35 % gold blend) — used when the
  # active pane's foreground command is `ssh`.
  sshChipBg = mixHex c.base02 c.base09 0.35;

  # tmux-agent-sidebar (hiroppy): on-demand sidebar showing every Claude
  # Code / Codex / OpenCode pane across sessions, with prompts, tool
  # calls, git state, worktrees. Distributed as a Rust binary + tmux
  # plugin scripts; we build the binary with rustPlatform and graft it
  # into the plugin's expected `bin/` path so the wizard never runs.
  #
  # On bumping `rev` below:
  #   1. The two `src/process.rs` `--replace-fail` patches further down fail
  #      the build loudly if upstream restructured the matcher — that's the
  #      safety net, no manual re-check needed beyond reading the error.
  #   2. Run `/plugin update tmux-agent-sidebar@hiroppy` inside Claude Code:
  #      the plugin install copies sources to a version-keyed cache dir
  #      (`~/.config/claude/plugins/cache/hiroppy/.../<version>/`), so
  #      plugin-side assets (hooks.json, slash commands, sidebar config)
  #      do NOT auto-update on a Nix bump even though the binary does (via
  #      the `~/.tmux/plugins/.../bin/` fallback in `hook.sh`).
  #   3. If upstream lands Nix-wrapper compat (trusting hooks over pid-scan,
  #      or accepting the `.<agent>-unwrapped` basename), drop the postPatch.
  tmux-agent-sidebar-src = pkgs.fetchFromGitHub {
    owner = "hiroppy";
    repo = "tmux-agent-sidebar";
    rev = "v0.10.1";
    hash = "sha256-OFSeoPwtJ3Dc9J1VCZIaXt+f4XC9Cb/qDjlxnVa3cK4=";
  };

  tmux-agent-sidebar-bin = pkgs.rustPlatform.buildRustPackage {
    pname = "tmux-agent-sidebar";
    version = "0.10.1";
    src = tmux-agent-sidebar-src;
    cargoLock.lockFile = tmux-agent-sidebar-src + "/Cargo.lock";
    # Tests rely on a live tmux server; skip to keep the build hermetic.
    doCheck = false;
    # Nix wraps every binary: `bin/claude` is a shell wrapper that
    # exec's `bin/.claude-unwrapped`, so the running process's basename
    # is `.claude-unwrapped`, not `claude`. Upstream's process detector
    # does an exact basename equality check, so it never identifies a
    # Nix-installed claude as the `claude` agent — pid-based cleanup
    # then strips `@pane_agent` from the pane every refresh tick and
    # the sidebar shows zero rows. Teach the matcher to also accept
    # the `.<agent>-unwrapped` form so Nix users get tracked.
    postPatch = ''
      substituteInPlace src/process.rs --replace-fail \
        "    if command_basename(&info.comm) == agent_name {" \
        "    let nix_wrapped = format!(\".{}-unwrapped\", agent_name);
        let is_match = |basename: &str| basename == agent_name || basename == nix_wrapped.as_str();
        if is_match(command_basename(&info.comm)) {"

      substituteInPlace src/process.rs --replace-fail \
        "    command_basename(command.trim_matches('\"')) == agent_name" \
        "    is_match(command_basename(command.trim_matches('\"')))"
    '';
  };

  tmux-agent-sidebar = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "tmux-agent-sidebar";
    version = "0.10.1";
    rtpFilePath = "tmux-agent-sidebar.tmux";
    src = tmux-agent-sidebar-src;
    # hook.sh + the entry script look for the binary at
    # `<plugin-dir>/bin/tmux-agent-sidebar` first. Symlinking the
    # rustPlatform output there bypasses the install-wizard entirely.
    postInstall = ''
      mkdir -p $target/bin
      ln -s ${tmux-agent-sidebar-bin}/bin/tmux-agent-sidebar $target/bin/tmux-agent-sidebar
    '';
  };

  # -------------------------------------------------------------------------
  # Status-left segment.
  # Layout:  [ <mode chip> · <session>[@host] ]  [SSH chip?]  <cwd helper>
  # The `@host` suffix is only emitted on non-GUI hosts (workstation hides
  # it; servers always show their hostname in gold). hasGui is the proxy —
  # it's the only existing flag that distinguishes workstations from servers
  # and keeps the actual hostnames out of public/.
  # -------------------------------------------------------------------------
  hostSuffix = lib.optionalString (!hasGui) "#[fg=${c.base09}]@#H#[fg=${c.base05}]";
in
{
  programs.tmux = {
    enable = true;

    clock24 = true;
    escapeTime = 0;
    keyMode = "vi";
    shortcut = "a";
    terminal = "tmux-256color";
    mouse = true;
    baseIndex = 1;
    plugins =
      (with pkgs.tmuxPlugins; [
        open # Open stuff with prefix+o
        pain-control # navigating panes etc
        sidebar # prefix+<tab> and prefix+<backspace>
        tmux-fzf # prefix+F
        # tmux-thumbs # copy/pasting stuff. prefix+<space>
        battery
        vim-tmux-navigator # Move around with <ctrl>+hjkl
        yank # Copy to system clipboard
        fzf-tmux-url # Find URLS with prefix+u
      ])
      ++ [
        # hiroppy/tmux-agent-sidebar: on-demand command palette over every
        # agent pane. `prefix + e` toggles in the current window,
        # `prefix + E` toggles globally. Hook-driven, no extra config.
        tmux-agent-sidebar
      ];

    extraConfig = ''
      set -sg terminal-overrides ",*:RGB"

      # Accept xterm-style modifyOtherKeys so unambiguous combos like
      # Ctrl+Shift+X reach tmux. Ghostty doesn't honor this protocol
      # (it speaks the kitty keyboard protocol only); see TODO.md for
      # the long-standing follow-up. Leaving the flag on so other
      # extkeys-aware terminals (kitty, wezterm, alacritty's modes,
      # foot, etc.) still benefit.
      set -s extended-keys on
      set -as terminal-features ",*:extkeys"

      # Permit OSC 52 / DCS passthrough so tools like `osc copy` reach
      # the outer terminal's clipboard from inside tmux. `on` covers
      # visible panes only; `all` would include hidden panes too, which
      # we don't need.
      set -g allow-passthrough on

      set-option -g default-shell $SHELL

      # Renumber windows on close so Ctrl+1..9 jumps stay contiguous.
      # (base-index / pane-base-index are set via programs.tmux.baseIndex.)
      set -g renumber-windows on

      # === Activity monitoring ================================================
      # Bell-only: flag windows on terminal bell, not on every byte of output.
      # Claude Code rings the bell on stop by default, so completed/blocked
      # sessions surface in the status bar without unrelated background output
      # (build logs, watchers, tail -f) lighting windows up constantly.
      set -g monitor-activity off
      set -g monitor-bell on
      set -g visual-activity off
      set -g visual-bell off

      # Loud, themed style for bell-flagged windows so attention-needed
      # sessions pop against the dim inactive window-status row.
      set -g window-status-bell-style "bg=default,fg=${c.base08},bold"

      # === Status bar ==========================================================
      set -g status on
      set -g status-position bottom
      set -g status-interval 5
      set -g status-justify absolute-centre
      # Bar default: base01 (slightly-lighter-than-terminal-bg) + base05
      # (full-contrast default fg). Inactive items can still go dim by
      # explicitly switching to base04 below; this default makes the bar
      # read as "primary content", not "dimmed chrome".
      set -g status-style "bg=${c.base01},fg=${c.base05}"

      set -g status-left-length 80
      set -g status-right-length 80

      # Mode chip atoms (single-letter, recolor for prefix/copy). Each chip
      # closes by switching style back to the surrounding left-box (base02).
      set -g @chip_normal "#[bg=${c.base03},fg=${c.base00},bold] N #[bg=${c.base02},fg=${c.base05},nobold]"
      set -g @chip_prefix "#[bg=${c.base09},fg=${c.base00},bold] P #[bg=${c.base02},fg=${c.base05},nobold]"
      set -g @chip_copy   "#[bg=${c.base0A},fg=${c.base00},bold] C #[bg=${c.base02},fg=${c.base05},nobold]"

      # SSH chip (round 4 T1): generic — no target host extraction.
      set -g @chip_ssh "#[bg=${sshChipBg},fg=${c.base09},bold]  SSH #[default]"

      # Window list: inactive intentionally dim (base04) so the active
      # window's accent box pops. Active recolors sympathetically with mode.
      set -g window-status-style "bg=default,fg=${c.base04}"
      set -g window-status-separator ""
      set -g window-status-format " #I:#W#{?window_zoomed_flag, ,} "
      set -g window-status-current-format "#{?client_prefix,#[bg=${c.base09}],#{?pane_in_mode,#[bg=${c.base0A}],#[bg=${c.base0D}]}}#[fg=${c.base00},bold] #I:#W#{?window_zoomed_flag, ,} #[default]"

      set -g status-left "#[bg=${c.base02},fg=${c.base05}] #{?client_prefix,#{@chip_prefix},#{?pane_in_mode,#{@chip_copy},#{@chip_normal}}} #{session_name}${hostSuffix} #[default] #{?#{==:#{pane_current_command},ssh},#{@chip_ssh} ,}#[fg=${c.base05}]#(tmux-cwd-icon #{pane_current_path})#[default] "

      # Right-side: git status (flat) · clock box (subtle mode tint).
      set -g status-right "#[fg=${c.base05}]#(tmux-git-status #{pane_current_path}) #[fg=${c.base03}]· #{?client_prefix,#[bg=${clockBgPrefix}],#{?pane_in_mode,#[bg=${clockBgCopy}],#[bg=${clockBgNormal}]}}#[fg=${c.base05}]  %a %H:%M #[default]"

      # === Pane focus =========================================================
      # Dim inactive panes so the focused one is the only surface at full
      # brightness. Re-tints all output in unfocused panes — if a TUI app
      # (nvim, btop, lazygit) ends up looking wrong when inactive, revert
      # these two lines and lean on pane-active-border-style instead.
      set -g window-style "fg=${c.base04},bg=default"
      set -g window-active-style "fg=${c.base05},bg=default"

      # Layered redundancy: bright accent border on the active pane, dim
      # line elsewhere. `heavy` upgrades the box-drawing glyph weight —
      # needs a font with U+2501 etc. (JetBrains Mono / SF Mono fine).
      set -g pane-border-style "fg=${c.base03}"
      set -g pane-active-border-style "fg=${c.base0D},bold"
      set -g pane-border-lines "heavy"

      # === Copy / clipboard ===================================================
      # Replace tmux-yank's default copy command (pbcopy on Darwin) with
      # `osc copy` so copies from remote tmux sessions (on remote servers) also
      # reach the local clipboard. `osc copy` writes OSC52 to the
      # controlling tty; tmux passes it through (allow-passthrough on),
      # SSH forwards it, the outermost terminal (Ghostty) captures it.
      set -g @override_copy_command "osc copy"

      # Mouse drag selects without auto-copying — parallels Ghostty's
      # `copy-on-select = false`. tmux-yank's default is
      # copy-pipe-and-cancel; we replace with `copy-selection-no-clear`
      # so the selection stays visible without writing the clipboard.
      unbind -T copy-mode-vi MouseDragEnd1Pane
      bind -N "[Copy] Select without copying (mouse drag)" \
        -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-selection-no-clear

      # Cmd+C bridge: Ghostty's Cmd+C falls through as Meta+C / \ec when
      # there's no Ghostty-level selection (always inside tmux mouse mode).
      # In copy-mode → pipe the selection to `osc copy`, keep selection.
      # Outside copy-mode → forward M-c so a nested SSH'd tmux gets the
      # same chance to handle it.
      bind -N "[Copy] Cmd+C bridge — copy selection via OSC52" -n M-c \
        if-shell -F '#{pane_in_mode}' \
          'send-keys -X copy-pipe-no-clear "osc copy"' \
          'send-keys M-c'

      # === Lazygit popup (matches Zellij Ctrl+g binding) ========================
      bind -N "[Tool] Open lazygit popup" -n C-g \
        display-popup -E -d "#{pane_current_path}" -w 90% -h 90% "lazygit"

      # === Window cycling (zellij-style unprefixed Ctrl+Left/Right) ===========
      bind -N "[Window] Previous window" -n C-Left  previous-window
      bind -N "[Window] Next window"     -n C-Right next-window

      # === Direct window jump: Ctrl+1..9 ======================================
      # Requires a terminal that emits the modifier (kitty keyboard protocol
      # or similar). Ghostty / Kitty / WezTerm send it; some legacy emulators
      # silently swallow Ctrl+digit.
      bind -N "[Window] Jump to window 1" -n C-1 select-window -t :1
      bind -N "[Window] Jump to window 2" -n C-2 select-window -t :2
      bind -N "[Window] Jump to window 3" -n C-3 select-window -t :3
      bind -N "[Window] Jump to window 4" -n C-4 select-window -t :4
      bind -N "[Window] Jump to window 5" -n C-5 select-window -t :5
      bind -N "[Window] Jump to window 6" -n C-6 select-window -t :6
      bind -N "[Window] Jump to window 7" -n C-7 select-window -t :7
      bind -N "[Window] Jump to window 8" -n C-8 select-window -t :8
      bind -N "[Window] Jump to window 9" -n C-9 select-window -t :9

      # === Pane cycling preserving zoom (Ctrl+Up/Down) ========================
      # `select-pane` auto-unzooms; if the window was zoomed before, re-zoom
      # after switching so the user can keep flipping between panes in
      # fullscreen without manually toggling zoom each time.
      #
      # Use tmux's `{ … }` command-group syntax (tmux 3.2+) instead of `\;`
      # inside single quotes — the latter is preserved literally inside a
      # quoted if-shell then-arg, so `select-pane` ends up receiving the
      # tail as positional args ("too many arguments; needs at most 0").
      bind -N "[Pane] Cycle up (preserve zoom)"   -n C-Up \
        if -F '#{window_zoomed_flag}' { select-pane -U ; resize-pane -Z } { select-pane -U }
      bind -N "[Pane] Cycle down (preserve zoom)" -n C-Down \
        if -F '#{window_zoomed_flag}' { select-pane -D ; resize-pane -Z } { select-pane -D }

      # vim/fzf tmux integration
      # https://github.com/christoomey/vim-tmux-navigator/issues/295#issuecomment-1021591011
      is_vim="children=(); i=0; pids=( $(ps -o pid=,tty= | grep -iE '#{s|/dev/||:pane_tty}' | awk '\{print $1\}') ); \
      while read -r c p; do [[ -n c && c -ne p && p -ne 0 ]] && children[p]+=\" $\{c\}\"; done <<< \"$(ps -Ao pid=,ppid=)\"; \
      while (( $\{#pids[@]\} > i )); do pid=$\{pids[i++]\}; pids+=( $\{children[pid]-\} ); done; \
      ps -o state=,comm= -p \"$\{pids[@]\}\" | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|n?vim?x?)(diff)?$'"

      bind -N "[Pane] Focus left (vim-aware)"  -n C-h run "($is_vim && tmux send-keys C-h) || tmux select-pane -L"
      bind -N "[Pane] Focus down (vim-aware)"  -n C-j run "($is_vim && tmux send-keys C-j) || tmux select-pane -D"
      bind -N "[Pane] Focus up (vim-aware)"    -n C-k run "($is_vim && tmux send-keys C-k) || tmux select-pane -U"
      bind -N "[Pane] Focus right (vim-aware)" -n C-l run "($is_vim && tmux send-keys C-l) || tmux select-pane -R"

      # Reload config with prefix+r. Home-manager places the rendered tmux
      # config at the XDG location, NOT ~/.tmux.conf.
      bind -N "[Tmux] Reload tmux.conf" r \
        source-file ~/.config/tmux/tmux.conf \; display-message "tmux.conf reloaded"

      # === Keybind discovery popups ===========================================
      # `prefix + ?` overrides the built-in raw `list-keys` page with a
      # fuzzy-filterable popup over the prefix table; selecting an entry
      # sends the prefix + key, so the bound action fires exactly as if
      # pressed. `prefix + /` is the same for the root (unprefixed) table
      # — overrides the default `describe-key`, which duplicates `?`.
      # See dotfiles/scripts/tmux-keys-popup.sh.
      unbind ?
      unbind /
      bind -N "[Tmux] Discover prefix-table binds (fzf)" ? \
        display-popup -E -w 90% -h 80% "tmux-keys-popup prefix"
      bind -N "[Tmux] Discover root-table binds (fzf)" / \
        display-popup -E -w 90% -h 80% "tmux-keys-popup root"
    '';
  };

  # Stable path for Claude Code's `/plugin marketplace add` command. The
  # marketplace registers a directory by absolute path; pointing it at a
  # hash-suffixed Nix store path would invalidate on every rebuild.
  # home-manager re-points this symlink each generation, so the path
  # stays valid while the underlying store path updates transparently.
  home.file.".tmux/plugins/tmux-agent-sidebar".source =
    "${tmux-agent-sidebar}/share/tmux-plugins/tmux-agent-sidebar";

  # OpenCode integration: a local plugin bridge (one JS file in
  # ~/.config/opencode/plugins/) that fires events at the sidebar's hook.sh.
  # That directory is the only way opencode loads a local plugin — the `plugin`
  # array in opencode.json is npm-only, and this bridge isn't published
  # standalone (it ships inside the tmux-plugin repo). Sourcing it from the
  # built plugin's `.opencode/` tree keeps it pinned to `rev` above.
  #
  # Unconditional, like the `.tmux/plugins` symlink: a headless devbox still
  # runs the sidebar over SSH, so a hasGui gate would wrongly drop it, and the
  # bridge is a no-op (hook.sh exits fast) where no sidebar is attached.
  xdg.configFile."opencode/plugins/tmux-agent-sidebar.js".source =
    "${tmux-agent-sidebar}/share/tmux-plugins/tmux-agent-sidebar/.opencode/plugins/tmux-agent-sidebar.js";

  # tmux-agent-sidebar bakes absolute Nix store paths into its `prefix +
  # e` keybinds and caches its binary path in `@agent_sidebar_bin` —
  # both pin the pre-rebuild plugin derivation. Stale sidebar TUI
  # processes also hold the previous binary in memory and keep doing
  # cleanup against the unpatched matcher. Source the new tmux.conf to
  # refresh the bindings, then SIGKILL the TUIs so the next `prefix + e`
  # spawns the patched binary.
  home.activation.reloadTmuxAgentSidebar = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if tmux info >/dev/null 2>&1; then
      tmux source-file "$HOME/.config/tmux/tmux.conf" >/dev/null 2>&1 || true
      pkill -9 -f tmux-agent-sidebar >/dev/null 2>&1 || true
    fi
  '';
}
