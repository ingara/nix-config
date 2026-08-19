# Dotfile-linking engine — pure helpers imported by the modules that own a
# dotfile-backed config dir. Two linking styles:
#
#   mkDirSymlink  — whole-dir symlink, for a clean config dir with no
#                   Nix-generated file mixed in (yabai/aerospace/wezterm/git-extra).
#   mkPerFileDots — per-file enumeration, for a live-edited dir that ALSO
#                   receives a Nix-generated sidecar (nvim/ghostty/sketchybar):
#                   per-file linking keeps ~/.config/<app> a real dir so the
#                   symlinked statics and the generated sidecar coexist, which a
#                   whole-dir symlink can't do.
#
# Both resolve a source via mkSource (the one mutable-vs-store primitive).
# `dotfilesRoot` defaults to this file's own anchor for public/dotfiles, so
# callers don't repeat it; the default is load-bearing for store-path stability
# (moving this file changes the non-mutable store paths).
{ lib }:
rec {
  # Anchored to *this* file's location: home/lib/ → public/dotfiles.
  defaultDotfilesRoot = ../../../../dotfiles;

  # Names to skip at every level of a recursive dotfile traversal. These are
  # repo-housekeeping files that would otherwise leak into ~/.config/<app>/ as a
  # side effect of whole-dir symlinks; per-file enumeration filters them out.
  # (mkDirSymlink does NOT apply this — a whole-dir symlink in mutable mode
  # points at the live dir and can't filter, so its callers must keep the source
  # dir clean.)
  defaultSkip = [
    "LICENSE"
    "README.md"
    ".git"
    ".gitignore"
    ".gitattributes"
    ".DS_Store"
    "stylua.toml"
    "selene.toml"
    "lua.yml"
    ".luarc.json"
  ];

  # Resolve a single dotfile's `source`: a live out-of-store symlink into the
  # working tree when `mutableDotfiles` is set (live-edit), else the file baked
  # into the store. `relPath` is the path relative to public/dotfiles (e.g.
  # "nvim/init.lua"). The single source-selection primitive — every other helper
  # here goes through it so the convention lives in one place.
  mkSource =
    {
      config,
      relPath,
      dotfilesRoot ? defaultDotfilesRoot,
    }:
    if config.myOptions.mutableDotfiles then
      config.lib.file.mkOutOfStoreSymlink "${config.myOptions.dotfiles.repoRoot}/dotfiles/${relPath}"
    else
      dotfilesRoot + "/${relPath}";

  # Whole-dir symlink: one xdg.configFile entry mapping a source dir to an XDG
  # path. For clean dirs with no Nix-generated sidecar. Returns an attrset to
  # merge into xdg.configFile.
  mkDirSymlink =
    {
      config,
      srcRel,
      xdgRel,
      dotfilesRoot ? defaultDotfilesRoot,
    }:
    {
      "${xdgRel}".source = mkSource {
        inherit config dotfilesRoot;
        relPath = srcRel;
      };
    };

  # Recurse a source dir, returning a list of file paths relative to the source
  # dir root. Filters out skip names at every level.
  listFilesRec =
    skip: srcPath:
    let
      entries = builtins.readDir srcPath;
      visit =
        name: type:
        if builtins.elem name skip then
          [ ]
        else if type == "directory" then
          map (sub: "${name}/${sub}") (listFilesRec skip "${srcPath}/${name}")
        else if type == "regular" || type == "symlink" then
          [ name ]
        else
          [ ];
    in
    lib.concatLists (lib.mapAttrsToList visit entries);

  # Build xdg.configFile entries for every file under a dotfile source dir.
  #   config       — HM config (for mutableDotfiles, repoRoot, mkOutOfStoreSymlink)
  #   srcRel       — path relative to dotfilesRoot (e.g. "nvim", "sketchybar")
  #   xdgRel       — path relative to ~/.config/    (e.g. "nvim", "sketchybar")
  #   skip         — basenames to skip at any depth (default: defaultSkip)
  #   extraExclude — source-relative paths to skip entirely (e.g.
  #                  [ "colors.sh" ] for sketchybar — Nix-generated)
  mkPerFileDots =
    {
      config,
      srcRel,
      xdgRel,
      skip ? defaultSkip,
      extraExclude ? [ ],
      dotfilesRoot ? defaultDotfilesRoot,
    }:
    let
      absSrc = dotfilesRoot + "/${srcRel}";
      files = builtins.filter (f: !(builtins.elem f extraExclude)) (listFilesRec skip absSrc);
      entry = file: {
        name = "${xdgRel}/${file}";
        value.source = mkSource {
          inherit config dotfilesRoot;
          relPath = "${srcRel}/${file}";
        };
      };
    in
    builtins.listToAttrs (map entry files);
}
