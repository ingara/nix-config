# Tmux multiplexer configuration.
#
# Plugins cover pane navigation, sidebar, fzf, battery, URL finder. C-hjkl in
# the root table is bound further down by `is_vim_or_herdr`, which forwards the
# chord into vim or herdr and otherwise selects a tmux pane.
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

  # Hex color blender — used for the clock-box subtle mode tint.
  # No stylix helper for this; ~20 LOC of pure Nix is the cheaper alternative
  # to a separate runtime tool or hardcoded per-theme color tables.
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

  # Pre-computed mode-aware tints for the clock box: ~20 % of base09 / base0A
  # blended over the box's base02. Loud enough to notice during prefix/copy,
  # quiet enough to ignore otherwise.
  clockBgNormal = c.base02;
  clockBgPrefix = mixHex c.base02 c.base09 0.20;
  clockBgCopy = mixHex c.base02 c.base0A 0.20;

  # SSH chip background (~35 % gold blend over base02) — used when the
  # active pane's foreground command is `ssh`.
  sshChipBg = mixHex c.base02 c.base09 0.35;

  # Status-left segment.
  # Layout:  [ <mode chip> · <session>[@host] ]  [SSH chip?]  <cwd helper>
  # The `@host` suffix is only emitted on non-GUI hosts (workstation hides
  # it; servers always show their hostname in gold). hasGui is the proxy —
  # it's the only existing flag that distinguishes workstations from servers
  # and keeps the actual hostnames out of public/.
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
    plugins = with pkgs.tmuxPlugins; [
      open # Open stuff with prefix+o
      pain-control # navigating panes etc
      sidebar # prefix+<tab> and prefix+<backspace>
      tmux-fzf # prefix+F
      # tmux-thumbs # copy/pasting stuff. prefix+<space>
      battery
      # Root-table C-hjkl comes from the is_vim_or_herdr binds below, which
      # render later and win. This stays for what those don't cover: C-hjkl
      # inside copy-mode-vi, and the previous-pane key.
      vim-tmux-navigator
      yank # Copy to system clipboard
      fzf-tmux-url # Find URLS with prefix+u
    ];

    extraConfig = ''
      set -sg terminal-overrides ",*:RGB"

      # Accept xterm-style modifyOtherKeys so unambiguous combos like
      # Ctrl+Shift+X reach tmux. Ghostty doesn't honor this protocol
      # (it speaks the kitty keyboard protocol only); tracked as a
      # long-standing upstream-watch item. Leaving the flag on so other
      # extkeys-aware terminals (kitty, wezterm, alacritty's modes,
      # foot, etc.) still benefit.
      set -s extended-keys on
      set -as terminal-features ",*:extkeys"

      # Emit modified special keys in libtickit CSI u form, not the xterm
      # `CSI 27;…~` default. Codex's tmux Shift+Enter fix (openai/codex #21943)
      # only requests modifyOtherKeys mode 2 for panes whose extended-keys-format
      # is csi-u; on the xterm default it never fires, so Shift+Enter reaches
      # Codex as a bare Enter (submit) instead of a newline. Global — every inner
      # app now gets csi-u for modified specials. Kept on `extended-keys on` (not
      # `always`) so tmux still forwards only to panes that request the mode.
      set -s extended-keys-format csi-u

      # Permit OSC 52 / DCS passthrough so tools like `osc copy` reach
      # the outer terminal's clipboard from inside tmux. `on` covers
      # visible panes only; `all` would include hidden panes too, which
      # we don't need.
      set -g allow-passthrough on

      set-option -g default-shell $SHELL

      # Renumber windows on close so Ctrl+1..9 jumps stay contiguous.
      # (base-index / pane-base-index are set via programs.tmux.baseIndex.)
      set -g renumber-windows on

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

      # Lazygit popup — matches the Zellij Ctrl+g binding.
      bind -N "[Tool] Open lazygit popup" -n C-g \
        display-popup -E -d "#{pane_current_path}" -w 90% -h 90% "lazygit"

      # Window cycling — zellij-style unprefixed Ctrl+Left/Right. The vertical
      # pair stays unbound so herdr's workspace nav reaches a nested herdr.
      bind -N "[Window] Previous window" -n C-Left  previous-window
      bind -N "[Window] Next window"     -n C-Right next-window

      # Direct window jump Ctrl+1..9 requires a terminal that emits the
      # modifier (kitty keyboard protocol or similar). Ghostty / Kitty /
      # WezTerm send it; some legacy emulators silently swallow Ctrl+digit.
      bind -N "[Window] Jump to window 1" -n C-1 select-window -t :1
      bind -N "[Window] Jump to window 2" -n C-2 select-window -t :2
      bind -N "[Window] Jump to window 3" -n C-3 select-window -t :3
      bind -N "[Window] Jump to window 4" -n C-4 select-window -t :4
      bind -N "[Window] Jump to window 5" -n C-5 select-window -t :5
      bind -N "[Window] Jump to window 6" -n C-6 select-window -t :6
      bind -N "[Window] Jump to window 7" -n C-7 select-window -t :7
      bind -N "[Window] Jump to window 8" -n C-8 select-window -t :8
      bind -N "[Window] Jump to window 9" -n C-9 select-window -t :9

      # vim/fzf tmux integration
      # https://github.com/christoomey/vim-tmux-navigator/issues/295#issuecomment-1021591011
      #
      # Matches herdr as well as vim, because herdr is itself a multiplexer: it
      # owns navigation inside its own panes and delegates back out with an
      # explicit `tmux select-pane` when it runs out of panes. Forwarding
      # unconditionally into a herdr pane is what makes that handoff possible.
      #
      # It also has to be here rather than relying on the vim match alone. The
      # walk collects the pane's whole descendant tree, and herdr's server is a
      # child of the client in that pane — so every process in every herdr pane
      # is in scope. Matching only vim means the decision silently depends on
      # whether some unrelated herdr pane happens to have an editor open.
      # `ps -e`, not a bare `ps`: this runs under tmux's run-shell, which has no
      # controlling terminal, so an unqualified `ps` lists only its own session —
      # every entry with tty `?` and none on the pane's tty. The collection then
      # comes back empty, the walk has nothing to traverse, and the predicate is
      # false for every pane, silently reducing C-hjkl to plain select-pane.
      is_vim_or_herdr="children=(); i=0; pids=( $(ps -eo pid=,tty= | grep -iE '#{s|/dev/||:pane_tty}' | awk '\{print $1\}') ); \
      while read -r c p; do [[ -n c && c -ne p && p -ne 0 ]] && children[p]+=\" $\{c\}\"; done <<< \"$(ps -Ao pid=,ppid=)\"; \
      while (( $\{#pids[@]\} > i )); do pid=$\{pids[i++]\}; pids+=( $\{children[pid]-\} ); done; \
      ps -o state=,comm= -p \"$\{pids[@]\}\" | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?(g?(view|n?vim?x?)(diff)?|herdr)$'"

      bind -N "[Pane] Focus left (vim/herdr-aware)"  -n C-h run "($is_vim_or_herdr && tmux send-keys C-h) || tmux select-pane -L"
      bind -N "[Pane] Focus down (vim/herdr-aware)"  -n C-j run "($is_vim_or_herdr && tmux send-keys C-j) || tmux select-pane -D"
      bind -N "[Pane] Focus up (vim/herdr-aware)"    -n C-k run "($is_vim_or_herdr && tmux send-keys C-k) || tmux select-pane -U"
      bind -N "[Pane] Focus right (vim/herdr-aware)" -n C-l run "($is_vim_or_herdr && tmux send-keys C-l) || tmux select-pane -R"

      # Reload config with prefix+r. Home-manager places the rendered tmux
      # config at the XDG location, NOT ~/.tmux.conf.
      bind -N "[Tmux] Reload tmux.conf" r \
        source-file ~/.config/tmux/tmux.conf \; display-message "tmux.conf reloaded"

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
}
