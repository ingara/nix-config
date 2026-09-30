# agent-github-router

`agent-github-router` selects an existing GitHub personal access token (PAT)
immediately before executing a command. Credential files must contain a classic
`ghp_` or fine-grained `github_pat_` token; OAuth and GitHub App tokens are not
accepted. The router does not store, mint, or refresh credentials.

The version 1 configuration schema is:

```json
{
  "version": 1,
  "executables": { "gh": "/path/to/gh", "git": "/path/to/git" },
  "ghConfigDir": "/isolated/gh/config/directory",
  "allowedGitConfigs": ["/path/to/agent/gitconfig"],
  "credentials": {
    "example": { "tokenFile": "/run/secrets/example-token" },
    "projects": { "tokenFile": "/run/secrets/projects-token" }
  },
  "ownerRoutes": { "example-owner": "example" },
  "projectsCredential": "projects"
}
```

The token files and configuration are supplied by the caller. Configuration
contains paths, never token values.

`projectsCredential` may be `null` when Projects access is intentionally
unavailable. `allowedGitConfigs` may be empty for a credential-helper-only
configuration.

## Commands

- `agent-github-router --config FILE credential get|store|erase` implements
  Git's credential-helper protocol. SOPS or another external owner manages the
  token files, so `store` and `erase` intentionally do nothing.
- `agent-github-router --config FILE gh -- ARGS...` transparently executes the
  configured `gh`, selecting a repository credential from the arguments,
  environment, or checkout.
- `agent-github-router --config FILE exec --repo OWNER/REPO -- COMMAND...` and
  `exec --credential NAME -- COMMAND...` explicitly select a credential for
  another program.
- `agent-github-router --config FILE doctor` checks the configuration,
  executables, and credential files without printing token contents.

The routing model and test matrix were inspired by
[`gh-app-auth`](https://github.com/AmadeusITGroup/gh-app-auth). This
implementation was written independently and does not copy its source code.
