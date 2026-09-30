# Credential-free Git UX shared across execution identities.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  dots = import ./lib/dotfiles.nix { inherit lib; };
  ghExtensions = [ pkgs.gh-pr-review ];
  gitIgnores = [
    ".omc"
    ".DS_Store"
    ".direnv"
    "shell.nix"
    ".envrc"
    "flake.lock"
    "flake.nix"
  ];
  gitSettings = {
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
  };
  gitIncludes = [
    { path = "~/.config/git/extra/aliases.gitconfig"; }
  ];
  lazygitSettings = {
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
  deltaOptions = {
    navigate = true;
    line-numbers = true;
    side-by-side = false;
    pager = "less";
    hyperlinks = true;
    keep-plus-minus-markers = true;
  };
in
{
  xdg.configFile = dots.mkDirSymlink {
    inherit config;
    srcRel = "git-extra";
    xdgRel = "git/extra";
  };

  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = lib.mkDefault false;
    # HM owns ~/.local/share/gh/extensions once any extension is declared
    # (gh-dash registers itself via its own module); imperative installs get
    # displaced, so every extension must be listed here.
    extensions = ghExtensions;
  };

  programs.git = {
    enable = true;
    ignores = gitIgnores;
    settings = gitSettings;

    # Included files must exist under dotfiles/git-extra/.
    includes = gitIncludes;
  };

  # Lazygit requires the multi-renderer array form.
  programs.lazygit = {
    enable = true;
    package = pkgs.lazygit;
    # Off: its shell integration installs an `lg` cd-on-exit wrapper that would
    # collide with the existing `lg = lazygit` portable CLI UX alias.
    enableFishIntegration = false;
    enableBashIntegration = false;
    enableZshIntegration = false;
    settings = lazygitSettings;
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = deltaOptions;
  };

  stylix.targets.lazygit.enable = true;

  myOptions.developerEnvironmentParity = {
    packages = {
      delta = {
        package = config.programs.delta.package;
        commands = [ "delta" ];
      };
      lazygit = {
        package = pkgs.lazygit;
        commands = [ "lazygit" ];
      };
    };
    surfaces.gitUx = {
      gh = {
        enable = config.programs.gh.enable;
        extensions = ghExtensions;
      };
      git = {
        enable = true;
        ignores = gitIgnores;
        settings = gitSettings;
        includes = gitIncludes;
      };
      lazygit = builtins.removeAttrs config.programs.lazygit [ "package" ] // {
        stylixTarget = config.stylix.targets.lazygit.enable;
      };
      delta = builtins.removeAttrs config.programs.delta [ "package" ];
    };
  };
}
