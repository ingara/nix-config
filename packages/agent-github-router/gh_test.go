package main

import (
	"bytes"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

func TestGHRepositoryPrecedence(t *testing.T) {
	cfg, _ := testConfig(t)
	tests := []struct {
		name string
		args []string
		env  []string
		want string
	}{
		{"explicit", []string{"issue", "view", "1", "--repo", "Beta/explicit"}, []string{"GH_REPO=alpha/environment"}, "beta/explicit"},
		{"compact explicit", []string{"issue", "view", "1", "-RBeta/compact"}, []string{"GH_REPO=alpha/environment"}, "beta/compact"},
		{"repo positional", []string{"repo", "view", "Beta/positional"}, []string{"GH_REPO=alpha/environment"}, "beta/positional"},
		{"repo positional after flag", []string{"repo", "view", "--branch", "feature", "Beta/positional"}, []string{"GH_REPO=alpha/environment"}, "beta/positional"},
		{"api endpoint", []string{"api", "repos/Beta/api/issues"}, []string{"GH_REPO=alpha/environment"}, "beta/api"},
		{"api endpoint after flags", []string{"api", "--paginate", "--method", "GET", "repos/Beta/api"}, []string{"GH_REPO=alpha/environment"}, "beta/api"},
		{"environment", []string{"issue", "view", "1"}, []string{"GH_REPO=Beta/environment"}, "beta/environment"},
		{"origin", []string{"issue", "view", "1"}, nil, "alpha/origin"},
		{"graphql environment", []string{"api", "graphql", "-f", "query=x"}, []string{"GH_REPO=Beta/graphql"}, "beta/graphql"},
		{"API placeholder environment", []string{"api", "repos/{owner}/{repo}/issues"}, []string{"GH_REPO=Beta/placeholder"}, "beta/placeholder"},
		{"API placeholder origin", []string{"api", "repos/{owner}/{repo}/issues"}, nil, "alpha/origin"},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			selected, err := selectGHCredential(cfg, test.args, test.env)
			if err != nil {
				t.Fatalf("selectGHCredential() error = %v", err)
			}
			if selected.Repository == nil || selected.Repository.String() != test.want {
				t.Fatalf("repository = %#v, want %q", selected.Repository, test.want)
			}
		})
	}
}

func TestGHExplicitSelectorsStopAtDoubleDash(t *testing.T) {
	cfg, _ := testConfig(t)
	selected, err := selectGHCredential(cfg, []string{"issue", "comment", "--", "--repo", "Beta/not-a-selector"}, nil)
	if err != nil {
		t.Fatal(err)
	}
	if selected.Repository.String() != "alpha/origin" {
		t.Fatalf("repository = %q", selected.Repository.String())
	}
}

func TestGHConflictingExplicitTargetsFail(t *testing.T) {
	cfg, _ := testConfig(t)
	for _, args := range [][]string{
		{"issue", "view", "--repo", "alpha/one", "-R", "beta/two"},
		{"issue", "view", "--repo", "alpha/one", "-Rbeta/two"},
		{"repo", "view", "alpha/one", "--repo", "beta/two"},
		{"api", "repos/alpha/one", "--repo", "beta/two"},
	} {
		if _, err := selectGHCredential(cfg, args, nil); err == nil || !strings.Contains(err.Error(), "conflicting") {
			t.Fatalf("selectGHCredential(%#v) error = %v", args, err)
		}
	}
}

func TestGHEmptyExplicitTargetsFail(t *testing.T) {
	cfg, gitConfig := testConfig(t)
	for _, args := range [][]string{{"--repo="}, {"-R="}, {"--repo", ""}, {"-R", ""}} {
		runner := &recordingExecutor{}
		ghArgs := append([]string{"--", "issue", "view"}, args...)
		if code := runGH(cfg, ghArgs, &bytes.Buffer{}, []string{"GIT_CONFIG_GLOBAL=" + gitConfig, "GH_REPO=alpha/environment"}, runner); code != exitPolicy {
			t.Fatalf("runGH(%#v) = %d", args, code)
		}
		if len(runner.calls) != 0 {
			t.Fatalf("child executed for %#v", args)
		}
	}
}

func TestGHRepositoryLookingFlagValueIsAmbiguous(t *testing.T) {
	cfg, _ := testConfig(t)
	for _, args := range [][]string{
		{"repo", "view", "--branch", "feature/topic"},
		{"api", "--input", "repos/Beta/payload", "graphql"},
	} {
		if _, err := selectGHCredential(cfg, args, []string{"GH_REPO=alpha/environment"}); err == nil || !strings.Contains(err.Error(), "ambiguous") {
			t.Fatalf("selectGHCredential(%#v) error = %v", args, err)
		}
	}
}

func TestGHPolicyBlocksAuthUnknownHostsAndUnknownOwners(t *testing.T) {
	cfg, _ := testConfig(t)
	tests := []struct {
		args []string
		env  []string
	}{
		{[]string{"auth", "status"}, nil},
		{[]string{"issue", "list", "--hostname", "enterprise.example"}, nil},
		{[]string{"issue", "list"}, []string{"GH_HOST=enterprise.example"}},
		{[]string{"issue", "list", "--repo", "unknown/repo"}, nil},
	}
	for _, test := range tests {
		if _, err := selectGHCredential(cfg, test.args, test.env); err == nil {
			t.Fatalf("selectGHCredential(%#v, %#v) succeeded", test.args, test.env)
		}
	}
}

func TestGHProjectUsesNamedCredential(t *testing.T) {
	cfg, _ := testConfig(t)
	selected, err := selectGHCredential(cfg, []string{"project", "list", "--owner", "example"}, nil)
	if err != nil {
		t.Fatal(err)
	}
	if selected.Credential != "projects" || selected.Repository != nil {
		t.Fatalf("selection = %#v", selected)
	}
	cfg.ProjectsCredential = nil
	if _, err := selectGHCredential(cfg, []string{"project", "list"}, nil); err == nil {
		t.Fatal("project succeeded without a Projects credential")
	}
}

func TestRunGHRequiresRecognizedAgentGitConfig(t *testing.T) {
	cfg, _ := testConfig(t)
	runner := &recordingExecutor{}
	environment := []string{"PATH=/bin", "GH_TOKEN=operator", "GH_HOST=enterprise.example"}
	args := []string{"--", "auth", "status", "--hostname", "enterprise.example"}
	if code := runGH(cfg, args, &bytes.Buffer{}, environment, runner); code != exitPolicy {
		t.Fatalf("runGH() = %d", code)
	}
	if len(runner.calls) != 0 {
		t.Fatalf("child executed: %#v", runner.calls)
	}
}

func TestRunGHAgentExecutionSelectsAndScrubs(t *testing.T) {
	cfg, gitConfig := testConfig(t)
	runner := &recordingExecutor{}
	environment := []string{
		"GIT_CONFIG_GLOBAL=" + gitConfig,
		"GH_REPO=Beta/Widget",
		"GH_TOKEN=operator",
		"GITHUB_TOKEN=operator",
	}
	args := []string{"--", "issue", "view", "1"}
	if code := runGH(cfg, args, &bytes.Buffer{}, environment, runner); code != 0 {
		t.Fatalf("runGH() = %d", code)
	}
	call := runner.calls[0]
	if !slices.Equal(call.args, args[1:]) {
		t.Fatalf("gh args = %#v", call.args)
	}
	if token, _ := envValue(call.env, "GH_TOKEN"); token != betaTestToken {
		t.Fatalf("GH_TOKEN = %q", token)
	}
	if _, ok := envValue(call.env, "GITHUB_TOKEN"); ok {
		t.Fatal("GITHUB_TOKEN was not scrubbed")
	}
	if repo, _ := envValue(call.env, "GH_REPO"); repo != "beta/widget" {
		t.Fatalf("GH_REPO = %q", repo)
	}
}

func TestRunGHLocalCommandsNeedNoRepositoryOrToken(t *testing.T) {
	localCommands := [][]string{
		{},
		{"--help"},
		{"--version"},
		{"version"},
		{"help"},
		{"help", "issue"},
		{"completion", "-s", "fish"},
		{"config", "list"},
		{"issue", "view", "--help"},
	}
	for _, ghArgs := range localCommands {
		t.Run(strings.Join(ghArgs, "_"), func(t *testing.T) {
			cfg, gitConfig := testConfig(t)
			cfg.Executables.Git = filepath.Join(t.TempDir(), "missing-git")
			for _, credential := range cfg.Credentials {
				if err := os.Remove(credential.TokenFile); err != nil {
					t.Fatal(err)
				}
			}
			runner := &recordingExecutor{}
			environment := []string{
				"GIT_CONFIG_GLOBAL=" + gitConfig,
				"GH_TOKEN=operator",
				"GITHUB_TOKEN=operator",
				"GH_ENTERPRISE_TOKEN=operator",
				"GITHUB_ENTERPRISE_TOKEN=operator",
				"GH_HOST=enterprise.example",
				"GH_REPO=wrong/repo",
			}
			args := append([]string{"--"}, ghArgs...)
			if code := runGH(cfg, args, &bytes.Buffer{}, environment, runner); code != 0 {
				t.Fatalf("runGH() = %d", code)
			}
			if len(runner.calls) != 1 || !slices.Equal(runner.calls[0].args, ghArgs) {
				t.Fatalf("execution = %#v", runner.calls)
			}
			for _, key := range []string{"GH_TOKEN", "GITHUB_TOKEN", "GH_ENTERPRISE_TOKEN", "GITHUB_ENTERPRISE_TOKEN", "GH_REPO"} {
				if _, ok := envValue(runner.calls[0].env, key); ok {
					t.Fatalf("%s was not scrubbed", key)
				}
			}
		})
	}
}

func TestRunGHAuthRemainsBlockedWithHelp(t *testing.T) {
	cfg, gitConfig := testConfig(t)
	for _, ghArgs := range [][]string{{"auth", "status"}, {"auth", "--help"}, {"help", "auth"}} {
		runner := &recordingExecutor{}
		var stderr bytes.Buffer
		args := append([]string{"--"}, ghArgs...)
		if code := runGH(cfg, args, &stderr, []string{"GIT_CONFIG_GLOBAL=" + gitConfig}, runner); code != exitPolicy {
			t.Fatalf("runGH(%#v) = %d", ghArgs, code)
		}
		if len(runner.calls) != 0 {
			t.Fatalf("auth child executed for %#v", ghArgs)
		}
		// The refusal stands, and it names the check that replaces it.
		message := stderr.String()
		for _, want := range []string{
			"gh auth commands are unavailable",
			"gh repo view <owner>/<repo> --json name",
			"owners: Alpha, Beta",
		} {
			if !strings.Contains(message, want) {
				t.Fatalf("stderr for %#v = %q, want it to contain %q", ghArgs, message, want)
			}
		}
	}
}

func TestAuthRefusalNamesOwnersInOrderAndLeaksNoCredentials(t *testing.T) {
	cfg, _ := testConfig(t)
	// Declared out of order, so a sorted list is the tested contract rather
	// than an accident of map iteration.
	cfg.OwnerRoutes = map[string]string{"Zulu": "alpha", "Alpha": "alpha", "Mike": "beta"}
	if err := cfg.validate(); err != nil {
		t.Fatal(err)
	}
	message := authRefusalMessage(cfg)
	if !strings.Contains(message, "owners: Alpha, Mike, Zulu") {
		t.Fatalf("authRefusalMessage() = %q", message)
	}
	// Owner names only: never a credential name, a token file, or a token.
	for _, secret := range []string{alphaTestToken, betaTestToken, projectsTestToken, "projects"} {
		if strings.Contains(message, secret) {
			t.Fatalf("authRefusalMessage() = %q, leaked %q", message, secret)
		}
	}
}

func TestAuthRefusalWithoutConfiguredOwners(t *testing.T) {
	cfg, _ := testConfig(t)
	cfg.OwnerRoutes = nil
	if err := cfg.validate(); err != nil {
		t.Fatal(err)
	}
	message := authRefusalMessage(cfg)
	if !strings.Contains(message, "gh auth commands are unavailable") {
		t.Fatalf("authRefusalMessage() = %q", message)
	}
	if strings.Contains(message, "gh repo view") {
		t.Fatalf("authRefusalMessage() = %q, suggested a check with no owner to run it against", message)
	}
}

func TestRunGHAPIStillRequiresRepositoryRouting(t *testing.T) {
	cfg, gitConfig := testConfig(t)
	cfg.Executables.Git = filepath.Join(t.TempDir(), "missing-git")
	runner := &recordingExecutor{}
	var stderr bytes.Buffer
	if code := runGH(cfg, []string{"--", "api", "graphql"}, &stderr, []string{"GIT_CONFIG_GLOBAL=" + gitConfig}, runner); code != exitPolicy {
		t.Fatalf("runGH() = %d, stderr = %q", code, stderr.String())
	}
	if len(runner.calls) != 0 {
		t.Fatal("API child executed without repository routing")
	}
}

func TestRunGHRejectsUnrecognizedAgentGitConfigWithExitFour(t *testing.T) {
	cfg, _ := testConfig(t)
	runner := &recordingExecutor{}
	environment := []string{"GIT_CONFIG_GLOBAL=" + filepath.Join(t.TempDir(), "other")}
	var stderr bytes.Buffer
	if code := runGH(cfg, []string{"--", "issue", "list"}, &stderr, environment, runner); code != exitPolicy {
		t.Fatalf("runGH() = %d, stderr = %q", code, stderr.String())
	}
	if len(runner.calls) != 0 {
		t.Fatal("child executed")
	}
}
