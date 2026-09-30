# Personal Git author, signing, transport, and credential authority.
{
  config,
  lib,
  ...
}:

let
  executionIdentity = config.myOptions.executionIdentity;
  gitAuthor = config.myOptions.gitAuthors.personal;
  userConfig = config.myOptions.user;
  inherit (config.myOptions) sshSignProgram gitCredentialHelper;
in
{
  assertions = [
    {
      assertion = executionIdentity == "personal";
      message = "git-identity.nix contains personal authority and requires executionIdentity = \"personal\"";
    }
  ];

  programs.gh.gitCredentialHelper.enable = true;

  programs.git = {
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
        inherit (gitAuthor) name email;
      };
      "url \"ssh://git@github.com/\"".insteadOf = "https://github.com/";
    }
    // lib.optionalAttrs (gitCredentialHelper != null) {
      credential.helper = gitCredentialHelper;
    };
  };
}
