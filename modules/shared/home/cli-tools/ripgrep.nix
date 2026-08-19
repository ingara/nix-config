_: {
  programs.ripgrep = {
    enable = true;
    # ripgrep binary stays in shared/packages.nix (see git.nix's lazygit
    # comment for the per-platform scope story); this avoids a second copy.
    package = null;
    arguments = [
      "--column"
      "--line-number"
      "--max-columns-preview"
      "--colors=line:style:bold"
    ];
  };
}
