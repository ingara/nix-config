package main

import (
	"os"
	"path/filepath"
	"testing"
)

const (
	alphaTestToken    = "ghp_alphaToken123"
	betaTestToken     = "github_pat_beta_Token456"
	projectsTestToken = "ghp_projectsToken789"
)

type execCall struct {
	command string
	args    []string
	env     []string
}

type recordingExecutor struct {
	calls []execCall
	err   error
}

func (executor *recordingExecutor) Exec(command string, args, environment []string) error {
	executor.calls = append(executor.calls, execCall{
		command: command,
		args:    append([]string(nil), args...),
		env:     append([]string(nil), environment...),
	})
	return executor.err
}

func testConfig(t *testing.T) (config, string) {
	t.Helper()
	dir := t.TempDir()
	alphaToken := filepath.Join(dir, "alpha.token")
	betaToken := filepath.Join(dir, "beta.token")
	projectsToken := filepath.Join(dir, "projects.token")
	for path, contents := range map[string]string{
		alphaToken:    alphaTestToken + "\n",
		betaToken:     betaTestToken + "\n",
		projectsToken: projectsTestToken + "\n",
	} {
		if err := os.WriteFile(path, []byte(contents), 0600); err != nil {
			t.Fatal(err)
		}
	}
	gitConfig := filepath.Join(dir, "gitconfig")
	if err := os.WriteFile(gitConfig, []byte("[credential]\n"), 0600); err != nil {
		t.Fatal(err)
	}
	ghConfig := filepath.Join(dir, "gh")
	if err := os.Mkdir(ghConfig, 0700); err != nil {
		t.Fatal(err)
	}
	projects := "projects"
	cfg := config{
		Version:           1,
		Executables:       executables{GH: "/bin/echo", Git: testGitExecutable(t, dir, "https://github.com/alpha/origin.git")},
		GHConfigDir:       ghConfig,
		AllowedGitConfigs: []string{gitConfig},
		Credentials: map[string]credential{
			"alpha":    {TokenFile: alphaToken},
			"beta":     {TokenFile: betaToken},
			"projects": {TokenFile: projectsToken},
		},
		OwnerRoutes: map[string]string{
			"Alpha": "alpha",
			"Beta":  "beta",
		},
		ProjectsCredential: &projects,
	}
	if err := cfg.validate(); err != nil {
		t.Fatal(err)
	}
	return cfg, gitConfig
}

func testGitExecutable(t *testing.T, dir, origin string) string {
	t.Helper()
	path := filepath.Join(dir, "git")
	contents := "#!/bin/sh\nprintf '%s\\n' '" + origin + "'\n"
	if err := os.WriteFile(path, []byte(contents), 0700); err != nil {
		t.Fatal(err)
	}
	return path
}

func writeConfig(t *testing.T, contents string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "config.json")
	if err := os.WriteFile(path, []byte(contents), 0600); err != nil {
		t.Fatal(err)
	}
	return path
}

func envValue(environment []string, key string) (string, bool) {
	return lookupEnv(environment, key)
}
