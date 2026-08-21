# Agent git identity: HTTPS with a per-owner token, instead of the operator's
# SSH key.
#
# The interactive gitconfig rewrites https://github.com/ to ssh://, so every git
# operation authenticates with an unscoped user SSH key and a scoped token has
# no effect on what an agent can push. Agents therefore get their own
# GIT_CONFIG_GLOBAL pointing at the file rendered here — HTTPS only, credentials
# from a per-owner token file, no fallback.
#
# Two mechanisms are load-bearing:
#   - GIT_CONFIG_SYSTEM must also be neutralised. It is a separate scope that
#     GIT_CONFIG_GLOBAL does not override, and git's own etc/gitconfig sets a
#     platform credential helper (osxkeychain) that satisfies pushes from cache
#     on its own, masking a bad token.
#   - `gh auth git-credential` is NOT usable as the helper: with an invalid
#     token in the environment it falls back to the keyring account and hands
#     git the operator's broad token, so scope would never bind.
#
# An owner absent from ownerTokens gets no credential and the operation fails.
# That is the mechanism keeping agents off arbitrary upstream repos: it does not
# depend on the token's own permissions being right.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myOptions.agentGit;
  userConfig = config.myOptions.user;

  enabled = cfg.ownerTokens != { };

  # Quote owner names so case treats them literally rather than as patterns.
  ownerCases = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      owner: tokenFile:
      "    ${lib.escapeShellArg (lib.toLower owner)}) tokenFile=${lib.escapeShellArg tokenFile} ;;"
    ) cfg.ownerTokens
  );

  agentAliases = pkgs.writeText "agent-git-aliases" (
    builtins.readFile ../../../../dotfiles/git-extra/aliases.gitconfig
  );

  credentialHelper = pkgs.writeShellApplication {
    name = "agent-git-credential";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      [ "''${1:-}" = get ] || exit 0

      protocol=""
      host=""
      owner=""
      while IFS= read -r line; do
        [ -z "$line" ] && break
        case "$line" in
          protocol=*) protocol=''${line#protocol=} ;;
          host=*) host=''${line#host=} ;;
          # Requires credential.useHttpPath, else git never sends the repo path
          # and there is nothing to key the owner off.
          path=*)
            owner=''${line#path=}
            owner=''${owner%%/*}
            ;;
        esac
      done

      [ "$protocol" = https ] && [ "$host" = github.com ] || exit 0
      owner=$(printf '%s' "$owner" | tr '[:upper:]' '[:lower:]')

      tokenFile=""
      case "$owner" in
      ${ownerCases}
        *) exit 0 ;;
      esac

      [ -r "$tokenFile" ] || exit 0
      printf 'username=x-access-token\npassword=%s\n' "$(cat "$tokenFile")"
    '';
  };

  agentGhConfig = pkgs.writeTextDir "config.yml" ''
    version: 1
  '';

  agentGhWrapper = pkgs.writeShellApplication {
    name = "gh";
    text = ''
      case "''${GIT_CONFIG_GLOBAL:-}" in
        "") exec ${lib.getExe pkgs.gh} "$@" ;;
        /nix/store/*-agent-gitconfig) ;;
        *)
          printf 'gh: unrecognized agent gitconfig; refusing operator credential fallback\n' >&2
          exit 4
          ;;
      esac

      if [ "''${1:-}" = auth ]; then
        printf 'gh: auth commands are unavailable in the agent environment\n' >&2
        exit 4
      fi

      args=("$@")
      for ((i = 0; i < ''${#args[@]}; i++)); do
        case "''${args[$i]}" in
          --hostname)
            i=$((i + 1))
            [ "''${args[$i]:-}" = github.com ] || {
              printf 'gh: only github.com is available in the agent environment\n' >&2
              exit 4
            }
            ;;
          --hostname=*)
            [ "''${args[$i]#--hostname=}" = github.com ] || {
              printf 'gh: only github.com is available in the agent environment\n' >&2
              exit 4
            }
            ;;
          -R | --repo)
            i=$((i + 1))
            repo_arg=''${args[$i]:-}
            case "$repo_arg" in
              */*/*)
                [ "''${repo_arg%%/*}" = github.com ] || {
                  printf 'gh: only github.com is available in the agent environment\n' >&2
                  exit 4
                }
                ;;
            esac
            ;;
          --repo=*)
            repo_arg=''${args[$i]#--repo=}
            case "$repo_arg" in
              */*/*)
                [ "''${repo_arg%%/*}" = github.com ] || {
                  printf 'gh: only github.com is available in the agent environment\n' >&2
                  exit 4
                }
                ;;
            esac
            ;;
        esac
      done

      if [ -n "''${GH_HOST:-}" ] && [ "$GH_HOST" != github.com ]; then
        printf 'gh: only github.com is available in the agent environment\n' >&2
        exit 4
      fi

      export GH_CONFIG_DIR=${agentGhConfig}
      export GH_HOST=github.com
      unset GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN

      tokenFile=""
      # Project routing supports the canonical `gh project ...` form.
      if [ "''${1:-}" = project ]; then
        tokenFile=${lib.escapeShellArg cfg.projectsToken}
      else
        if ! remote=$(${lib.getExe pkgs.git} remote get-url origin 2>/dev/null); then
          printf 'gh: no origin remote; refusing operator credential fallback\n' >&2
          exit 4
        fi

        case "$remote" in
          https://github.com/*) repo=''${remote#https://github.com/} ;;
          ssh://git@github.com/*) repo=''${remote#ssh://git@github.com/} ;;
          git@github.com:*) repo=''${remote#git@github.com:} ;;
          *)
            printf 'gh: origin is not a supported GitHub remote; refusing operator credential fallback\n' >&2
            exit 4
            ;;
        esac

        owner=''${repo%%/*}
        owner=''${owner,,}
        case "$owner" in
        ${ownerCases}
          *) tokenFile="" ;;
        esac
      fi

      if [ -z "$tokenFile" ] || [ ! -r "$tokenFile" ]; then
        printf 'gh: no agent credential for this command; refusing operator credential fallback\n' >&2
        exit 4
      fi

      GH_TOKEN=$(<"$tokenFile")
      if [ -z "$GH_TOKEN" ]; then
        printf 'gh: agent credential file is empty\n' >&2
        exit 4
      fi
      export GH_TOKEN
      unset GITHUB_TOKEN
      exec ${lib.getExe pkgs.gh} "$@"
    '';
  };

  agentGh = pkgs.symlinkJoin {
    name = "gh-agent-aware-${pkgs.gh.version}";
    paths = [ pkgs.gh ];
    inherit (pkgs.gh) meta;
    postBuild = ''
      rm "$out/bin/gh"
      ln -s ${lib.getExe agentGhWrapper} "$out/bin/gh"
    '';
  };

  # insteadOf only rewrites literal prefixes, while Git accepts other SSH URL
  # spellings from remotes and submodules. Fail closed before an ambient SSH
  # agent can satisfy any form the ergonomic rewrites miss.
  sshTransportDisabled = pkgs.writeShellApplication {
    name = "agent-git-ssh-disabled";
    text = ''
      printf '%s\n' 'agent-git: ssh transport disabled; use https' >&2
      exit 1
    '';
  };

  # Hand-written INI rather than generators.toGitINI: the credential subsection
  # and the repeated insteadOf keys are easier to keep exact this way, and this
  # file is a security control worth reading literally.
  agentGitconfig = pkgs.writeText "agent-gitconfig" ''
    # Generated by agent-git.nix. Lives in the store, so it is read-only —
    # `git config --global` fails for agents by design, which stops a session
    # from re-adding the ssh rewrite this file exists to remove. Not a boundary
    # (`git -c` and GIT_CONFIG_GLOBAL are still the agent's to set), just the
    # right default.
    [user]
      name = ${userConfig.fullName}
      email = ${userConfig.email}
    ${lib.optionalString (cfg.signingKeyFile != "") ''
      signingkey = ${cfg.signingKeyFile}
    ''}
    [credential]
      useHttpPath = true
    [credential "https://github.com"]
      helper = ${lib.getExe credentialHelper}
    [url "https://github.com/"]
      insteadOf = ssh://git@github.com/
      insteadOf = git@github.com:
    ${lib.optionalString (cfg.signingKeyFile != "") ''
      [gpg]
        format = ssh
      [gpg "ssh"]
        program = ssh-keygen
      ${lib.optionalString (cfg.allowedSignersFile != "") ''
        allowedSignersFile = ${cfg.allowedSignersFile}
      ''}
      [commit]
        gpgsign = true
      [tag]
        gpgsign = true
    ''}
    [init]
      defaultBranch = main
    [pull]
      rebase = true
      default = current
    [push]
      default = current
    [rerere]
      enabled = true
    [core]
      editor = nvim
      sshCommand = ${lib.getExe sshTransportDisabled}
    # Ensure port-qualified URLs invoke the blocker instead of Git rejecting
    # the custom command as an argument-less "simple" SSH variant first.
    [ssh]
      variant = ssh
    [filter "lfs"]
      clean = git-lfs clean -- %f
      process = git-lfs filter-process
      required = true
      smudge = git-lfs smudge -- %f
    [delta]
      hyperlinks = true
      keep-plus-minus-markers = true
      line-numbers = true
      navigate = true
      pager = less
      side-by-side = false
    [interactive]
      diffFilter = ${lib.getExe pkgs.delta} --color-only
    [pager]
      blame = ${lib.getExe pkgs.delta}
      diff = ${lib.getExe pkgs.delta}
      log = ${lib.getExe pkgs.delta}
      show = ${lib.getExe pkgs.delta}
    [include]
      path = ${agentAliases}
  '';
in
lib.mkIf enabled {
  # Options live in shared/options.nix — the myOptions tree is forwarded into
  # home-manager, so a system-only declaration breaks HM's copy.
  myOptions.agentGit.gitconfigPath = "${agentGitconfig}";

  home-manager.sharedModules = [
    {
      programs.gh.package = agentGh;
    }
  ];
}
