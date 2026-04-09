# Dotfiles

Dotfiles are `mkOutOfStoreSymlink`ed — edits are live without rebuilds.

Shell scripts are the exception: files in `scripts/` must be wrapped via `writeShellScriptBin` in `public/modules/shared/packages.nix` to land in `$PATH`.

## Neovim

Base is **LazyVim**. Check `lazyvim.plugins.extras.*` imports in `lua/config/lazy.lua` before extending any plugin — extras may already register keybinds and commands.
