# mise — polyglot runtime version manager. Replaces asdf/nvm/pyenv.
_: {
  programs.mise = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
    # corepack shims (pnpm/yarn) live inside each mise-installed node, so they
    # run on the project's pinned node instead of the system fallback.
    globalConfig.settings.node.corepack = true;
  };
}
