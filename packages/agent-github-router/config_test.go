package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestLoadConfigRejectsMalformedAndAmbiguousConfig(t *testing.T) {
	validFields := `
    "executables":{"gh":"/bin/gh","git":"/bin/git"},
    "ghConfigDir":"/tmp/gh",
    "allowedGitConfigs":[],
    "credentials":{"one":{"tokenFile":"/tmp/token"}},
    "projectsCredential":null`
	tests := map[string]string{
		"unknown field":      `{"version":1,` + validFields + `,"ownerRoutes":{},"surprise":true}`,
		"wrong version":      `{"version":2,` + validFields + `,"ownerRoutes":{}}`,
		"unknown credential": `{"version":1,` + validFields + `,"ownerRoutes":{"owner":"missing"}}`,
		"owner collision":    `{"version":1,` + validFields + `,"ownerRoutes":{"Owner":"one","owner":"one"}}`,
		"trailing JSON":      `{"version":1,` + validFields + `,"ownerRoutes":{}} {}`,
	}
	for name, contents := range tests {
		t.Run(name, func(t *testing.T) {
			if _, err := loadConfig(writeConfig(t, contents)); err == nil {
				t.Fatal("loadConfig() succeeded")
			}
		})
	}
}

func TestOwnerCollisionDiagnosticIsDeterministic(t *testing.T) {
	contents := `{
      "version":1,
      "executables":{"gh":"/bin/gh","git":"/bin/git"},
      "ghConfigDir":"/tmp/gh",
      "allowedGitConfigs":[],
      "credentials":{"one":{"tokenFile":"/tmp/token"}},
      "ownerRoutes":{"owner":"one","Owner":"one"},
      "projectsCredential":null
    }`
	_, err := loadConfig(writeConfig(t, contents))
	want := `config: owner routes "Owner" and "owner" collide case-insensitively`
	if err == nil || err.Error() != want {
		t.Fatalf("loadConfig() error = %v, want %q", err, want)
	}
}

func TestLoadConfigAllowsCredentialOnlyConfiguration(t *testing.T) {
	contents := `{
      "version":1,
      "executables":{"gh":"/bin/gh","git":"/bin/git"},
      "ghConfigDir":"/tmp/gh",
      "allowedGitConfigs":[],
      "credentials":{"one":{"tokenFile":"/tmp/token"}},
      "ownerRoutes":{"Owner":"one"},
      "projectsCredential":null
    }`
	cfg, err := loadConfig(writeConfig(t, contents))
	if err != nil {
		t.Fatalf("loadConfig() error = %v", err)
	}
	if cfg.ProjectsCredential != nil {
		t.Fatal("projectsCredential was not nil")
	}
	if credential, ok := cfg.credentialForOwner("oWnEr"); !ok || credential != "one" {
		t.Fatalf("case-insensitive route = %q, %v", credential, ok)
	}
}

func TestTokenForCredentialValidatesGitHubPATShape(t *testing.T) {
	cfg, _ := testConfig(t)
	tokenFile := cfg.Credentials["alpha"].TokenFile
	tests := map[string]struct {
		token string
		valid bool
	}{
		"classic PAT":          {token: "ghp_validToken123\n", valid: true},
		"fine-grained PAT":     {token: "github_pat_valid_Token456\n", valid: true},
		"pasted return symbol": {token: "ghp_validToken123\u23ce"},
		"trailing space":       {token: "ghp_validToken123 "},
		"empty payload":        {token: "ghp_"},
		"wrong token kind":     {token: "gho_oauthToken123"},
	}
	for name, test := range tests {
		t.Run(name, func(t *testing.T) {
			if err := os.WriteFile(tokenFile, []byte(test.token), 0600); err != nil {
				t.Fatal(err)
			}
			_, err := cfg.tokenForCredential("alpha")
			if test.valid && err != nil {
				t.Fatalf("tokenForCredential() error = %v", err)
			}
			if !test.valid && err == nil {
				t.Fatal("tokenForCredential() accepted invalid token")
			}
			if err != nil && strings.Contains(err.Error(), strings.TrimSpace(test.token)) {
				t.Fatal("tokenForCredential() error disclosed token")
			}
		})
	}
}

func TestValidateAgentGitConfigAcceptsRealpath(t *testing.T) {
	cfg, gitConfig := testConfig(t)
	symlink := filepath.Join(t.TempDir(), "gitconfig-link")
	if err := os.Symlink(gitConfig, symlink); err != nil {
		t.Fatal(err)
	}
	if err := cfg.validateAgentGitConfig(symlink); err != nil {
		t.Fatalf("validateAgentGitConfig() error = %v", err)
	}
	if err := cfg.validateAgentGitConfig(filepath.Join(t.TempDir(), "other")); err == nil || !strings.Contains(err.Error(), "unrecognized") {
		t.Fatalf("unexpected mismatch error: %v", err)
	}
}
