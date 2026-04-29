# Git and git-adjacent tooling.
#
# - `programs.git`   — config + signing. Signing key + sshSignProgram pulled
#                      from `myOptions.user` and `myOptions.sshSignProgram`
#                      so work / home hosts can override the signer.
# - `programs.gh`    — GitHub CLI (auth tokens live outside this tree).
# - `programs.delta` — diff viewer, enabled as git's pager.
{
  config,
  lib,
  ...
}:

let
  userConfig = config.myOptions.user;
  inherit (config.myOptions) sshSignProgram gitCredentialHelper;
  name = userConfig.fullName;
  inherit (userConfig) email;
in
{
  programs.gh = {
    enable = true;
  };

  programs.git = {
    enable = true;
    ignores = [
      ".DS_Store"
      ".direnv"
      "shell.nix"
      ".envrc"
      "flake.lock"
      "flake.nix"
    ];

    signing = {
      signByDefault = true;
      format = "ssh";
      key = userConfig.signingKey;
    }
    // lib.optionalAttrs (sshSignProgram != null) {
      signer = sshSignProgram;
    };

    settings = {
      user = {
        inherit name;
        inherit email;
      };
      core.editor = "nvim";
      init.defaultBranch = "main";
      pull = {
        default = "current";
        rebase = true;
      };
      push.default = "current";
      rerere.enabled = true;
      "filter \"lfs\"" = {
        process = "git-lfs filter-process";
        required = true;
        clean = "git-lfs clean -- %f";
        smudge = "git-lfs smudge -- %f";
      };
      "url \"ssh://git@github.com/\"".insteadOf = "https://github.com/";
    }
    // lib.optionalAttrs (gitCredentialHelper != null) {
      credential.helper = gitCredentialHelper;
    };

    # Include all git config files from git-extra directory
    # To add more files: just add them to this list and to dotfiles/git-extra/
    includes = [
      { path = "~/.config/git/extra/aliases.gitconfig"; }
    ];
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
      side-by-side = false;
      pager = "less";
      hyperlinks = true;
      keep-plus-minus-markers = true;
    };
  };
}
