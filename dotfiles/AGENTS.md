# Dotfiles

Dotfiles are per-file `mkOutOfStoreSymlink`ed — edits are live without rebuilds.
Each file in `public/dotfiles/<app>/` becomes an individual symlink at
`~/.config/<app>/<file>`, so Nix-generated files (theme files, palette files) can
coexist alongside live-edit dotfiles in the same `~/.config/<app>/` directory.

Shell scripts are the exception: files in `scripts/` must be wrapped via
`writeShellScriptBin` in `public/modules/shared/packages.nix` to land in
`$PATH`.

## Neovim

Base is **LazyVim**. Check `lazyvim.plugins.extras.*` imports in
`lua/config/lazy.lua` before extending any plugin — extras may already register
keybinds and commands.

## Theming

Single source of truth: `myOptions.theme.scheme` in
`public/modules/shared/options.nix`. Changing this value + `just switch` /
`just deploy-*` recolors every themed surface.

### How theme flows

1. `myOptions.theme.scheme` → resolved to a base16 YAML via
   `inputs.tinted-schemes/base16/<scheme>.yaml`
2. `public/modules/shared/home/theme.nix` exposes `config.lib.myTheme.*`
   (scheme name, polarity, YAML path)
3. Per-platform Stylix wiring reads `myTheme` and sets
   `stylix.base16Scheme` / `stylix.polarity`
4. Stylix auto-themes apps via its targets (starship, tmux, fish, fzf, bat,
   wezterm, ghostty, zellij, jankyborders, KDE Plasma)
5. Custom adapters handle apps Stylix doesn't support:
   - `nvim-theme.nix` → generates `nvim/lua/theme.lua` (palette + colorscheme
     name)
   - `sketchybar.nix` → generates `sketchybar/colors.sh` (30 `COLOR_*` vars)
   - `terminal-themes.nix` → generates `ghostty/themes/stylix` and
     `zellij/themes/stylix.kdl`

### Edit patterns

| Pattern                                    | Apps                                                                                                                         | Workflow                                                    |
| ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| Per-file `mkOutOfStoreSymlink` (live-edit) | nvim, ghostty config, zellij config.kdl, sketchybar plugins, lazygit, aerospace, yabai, skhd, wezterm/extra, git/extra       | Edit `~/.config/<app>/<file>` directly; changes are instant |
| Nix-generated (rebuild required)           | starship, tmux, fish, fzf, bat, wezterm.lua (HM extraConfig), KDE Plasma, GTK/Qt, `theme.lua`, `colors.sh`, `themes/stylix*` | Edit the Nix module; run `just switch`                      |

### Adding a new theme

Add the scheme name to the enum in `public/modules/shared/options.nix`. The name
must match a YAML file in `tinted-theming/schemes` (`base16/<name>.yaml`). If the
scheme needs a non-obvious nvim plugin colorscheme name, add a mapping entry in
`public/modules/shared/home/nvim-theme.nix`'s `pluginColorscheme` attrset.

### Nvim specifics

Nvim is explicitly excluded from Stylix (`stylix.targets.neovim.enable = false`).
Instead, `nvim-theme.nix` generates `lua/theme.lua` which exposes `M.scheme`,
`M.colorscheme`, `M.polarity`, and `M.colors` (full base16 palette with `#`
prefix). The dotfile `lua/plugins/colorscheme.lua` reads this and activates the
matching plugin. `lua/theme_reactive.lua` (also a dotfile) drives reactive.nvim
cursor colors from the palette — edit it live to tweak mode highlights.
