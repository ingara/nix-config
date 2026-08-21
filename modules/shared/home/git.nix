# Git and git-adjacent tooling (git, gh, delta, lazygit).
#
# Signing key + sshSignProgram pull from `myOptions.user` and
# `myOptions.sshSignProgram` so work / home hosts can override the signer.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  userConfig = config.myOptions.user;
  inherit (config.myOptions) sshSignProgram gitCredentialHelper;
  name = userConfig.fullName;
  inherit (userConfig) email;
  dots = import ./lib/dotfiles.nix { inherit lib; };
in
{
  # git-extra (clean dir → whole-dir symlink) holds the files programs.git.includes
  # points at below.
  xdg.configFile = dots.mkDirSymlink {
    inherit config;
    srcRel = "git-extra";
    xdgRel = "git/extra";
  };

  programs.gh = {
    enable = true;
    # HM owns ~/.local/share/gh/extensions once any extension is declared
    # (gh-dash registers itself via its own module); imperative installs get
    # displaced, so every extension must be listed here.
    extensions = [ pkgs.gh-pr-review ];
  };

  programs.git = {
    enable = true;
    ignores = [
      ".omc"
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

    # Files here must also exist under dotfiles/git-extra/ (symlinked above).
    includes = [
      { path = "~/.config/git/extra/aliases.gitconfig"; }
    ];
  };

  # lazygit config only — the binary comes from shared/packages.nix;
  # `package = null` avoids a second, HM-owned copy.
  # git.diffRenderers is lazygit's multi-renderer array form (verified schema).
  programs.lazygit = {
    enable = true;
    package = null;
    # Off: its shell integration installs an `lg` cd-on-exit wrapper that would
    # collide with the existing `lg = lazygit` alias (aliases.nix).
    enableFishIntegration = false;
    enableBashIntegration = false;
    enableZshIntegration = false;
    settings = {
      git.diffRenderers = [
        {
          colorArg = "always";
          command = "delta --paging=never";
        }
      ];
      customCommands = [
        {
          key = "!";
          description = "Run git alias!";
          command = "git {{index .PromptResponses 0}}";
          context = "global";
          prompts = [
            {
              type = "input";
              title = "Command (git alias)";
            }
          ];
          output = "terminal";
        }
      ];
    };
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
