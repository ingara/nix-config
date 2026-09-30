# Dotfiles

Dotfiles are linked per file. Profiles with `myOptions.mutableDotfiles = true`
use `mkOutOfStoreSymlink`, so edits are live without rebuilds; immutable
profiles use store-backed sources. Each file in `public/dotfiles/<app>/` lands
at `~/.config/<app>/<file>`, so Nix-generated files (theme files, palette files)
can coexist with source dotfiles in the same `~/.config/<app>/` directory.

Shell scripts are the exception: files in `scripts/` must be wrapped by their
owning Nix module to land in `$PATH`. Prefer `writeShellApplication` when the
script invokes external runtime dependencies.

Launchd plugins do not inherit interactive-shell PATH. Declare external tools
through the owning service's runtime-package option; for SketchyBar, use
`services.sketchybar.extraPackages`. Verify with the generated plist's
environment. Literal `$HOME` and `$USER` in plist PATH entries are not
expanded.

## Neovim

Base is **LazyVim**. Check `lazyvim.plugins.extras.*` imports in
`lua/config/lazy.lua` before extending any plugin — extras may already register
keybinds and commands.

## Tmux

Tmux is the maintained classic multiplexer. Its configuration lives in
`public/modules/shared/home/tmux.nix` and requires a rebuild after changes.

## Theming

Single source of truth: `myOptions.theme.scheme` in
`public/modules/shared/options.nix`. Changing this value + `just switch` /
`just deploy-*` recolors every themed surface.

### How theme flows

1. `myOptions.theme.scheme` → resolved to a base16 YAML via
   `inputs.tinted-schemes/base16/<scheme>.yaml`
2. `public/modules/shared/home/theme.nix` exposes `config.lib.myTheme.*`
   (scheme name, polarity, YAML path)
3. `cli-ux.nix` applies that palette to portable terminal targets (starship,
   fish, fzf, bat); provider modules such as `tmux.nix` own their targets
4. `stylix-base.nix` layers global fonts, terminal opacity, and graphical
   targets onto full user profiles; terminal font and opacity flow from those
   globals, so don't set them per-app
5. Custom adapters handle apps that need more control than a Stylix target:
   - `nvim-theme.nix` → generates `nvim/lua/theme.lua` (palette + colorscheme
     name)
   - `sketchybar.nix` → generates `sketchybar/colors.sh` (30 `COLOR_*` vars)

### Edit patterns

| Pattern                          | Apps                                                                                                                                                                   | Workflow                                                   |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| Per-file source links            | nvim, sketchybar plugins, aerospace, yabai, skhd, wezterm/extra, git/extra                                                                                             | Live in mutable profiles; rebuild in store-backed profiles |
| Nix-generated (rebuild required) | starship, tmux, fish, fzf, bat, ghostty (`programs.ghostty`), lazygit (`programs.lazygit`), wezterm.lua (HM extraConfig), KDE Plasma, GTK/Qt, `theme.lua`, `colors.sh` | Edit the Nix module; run `just switch`                     |

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
