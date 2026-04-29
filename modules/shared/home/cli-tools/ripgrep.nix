_: {
  programs.ripgrep = {
    enable = true;
    arguments = [
      "--column"
      "--line-number"
      "--max-columns-preview"
      "--colors=line:style:bold"
    ];
  };
}
