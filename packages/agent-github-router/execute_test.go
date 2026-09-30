package main

import (
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"syscall"
	"testing"
)

func TestControlledEnvironmentScrubsGitHubState(t *testing.T) {
	cfg, _ := testConfig(t)
	repo := repository{Owner: "Alpha", Name: "Widget"}
	base := []string{
		"PATH=/bin", "GH_TOKEN=operator", "GITHUB_TOKEN=operator",
		"GH_ENTERPRISE_TOKEN=operator", "GITHUB_ENTERPRISE_TOKEN=operator",
		"GH_CONFIG_DIR=/operator", "GH_HOST=enterprise.example", "GH_REPO=wrong/repo",
	}
	environment := controlledEnvironment(base, cfg, "selected-secret", &repo)
	for key, want := range map[string]string{
		"PATH": "/bin", "GH_TOKEN": "selected-secret", "GH_CONFIG_DIR": cfg.GHConfigDir,
		"GH_HOST": "github.com", "GH_REPO": "alpha/widget",
	} {
		if got, ok := envValue(environment, key); !ok || got != want {
			t.Fatalf("%s = %q, %v; want %q", key, got, ok, want)
		}
	}
	for _, key := range []string{"GITHUB_TOKEN", "GH_ENTERPRISE_TOKEN", "GITHUB_ENTERPRISE_TOKEN"} {
		if _, ok := envValue(environment, key); ok {
			t.Fatalf("%s was not scrubbed", key)
		}
	}
}

func TestTokenlessEnvironmentScrubsTokensAndRepository(t *testing.T) {
	cfg, _ := testConfig(t)
	environment := tokenlessEnvironment([]string{
		"PATH=/bin", "GH_TOKEN=operator", "GITHUB_TOKEN=operator",
		"GH_ENTERPRISE_TOKEN=operator", "GITHUB_ENTERPRISE_TOKEN=operator",
		"GH_CONFIG_DIR=/operator", "GH_HOST=enterprise.example", "GH_REPO=wrong/repo",
	}, cfg)
	for _, key := range []string{"GH_TOKEN", "GITHUB_TOKEN", "GH_ENTERPRISE_TOKEN", "GITHUB_ENTERPRISE_TOKEN", "GH_REPO"} {
		if _, ok := envValue(environment, key); ok {
			t.Fatalf("%s was not scrubbed", key)
		}
	}
	if value, _ := envValue(environment, "GH_CONFIG_DIR"); value != cfg.GHConfigDir {
		t.Fatalf("GH_CONFIG_DIR = %q", value)
	}
	if value, _ := envValue(environment, "GH_HOST"); value != "github.com" {
		t.Fatalf("GH_HOST = %q", value)
	}
}

func TestExplicitExecSelectsRepoAndNamedCredential(t *testing.T) {
	cfg, _ := testConfig(t)
	for name, args := range map[string][]string{
		"repository": {"--repo", "Beta/Widget", "--", "tool", "arg"},
		"named":      {"--credential", "projects", "--", "tool", "arg"},
	} {
		t.Run(name, func(t *testing.T) {
			selected, command, commandArgs, err := parseExplicitExec(cfg, args)
			if err != nil {
				t.Fatalf("parseExplicitExec() error = %v", err)
			}
			if command != "tool" || !slices.Equal(commandArgs, []string{"arg"}) {
				t.Fatalf("command = %q %#v", command, commandArgs)
			}
			if name == "repository" && (selected.Credential != "beta" || selected.Repository.String() != "beta/widget") {
				t.Fatalf("selection = %#v", selected)
			}
			if name == "named" && (selected.Credential != "projects" || selected.Repository != nil) {
				t.Fatalf("selection = %#v", selected)
			}
		})
	}
}

func TestExplicitExecRejectsAmbiguousSelectors(t *testing.T) {
	cfg, _ := testConfig(t)
	for _, args := range [][]string{
		{"--repo", "alpha/one", "--credential", "alpha", "--", "tool"},
		{"--repo", "alpha/one", "--repo", "alpha/one", "--", "tool"},
		{"--", "tool"},
		{"--credential", "missing", "--", "tool"},
	} {
		if _, _, _, err := parseExplicitExec(cfg, args); err == nil {
			t.Fatalf("parseExplicitExec(%#v) succeeded", args)
		}
	}
}

func TestExecuteSelectedKeepsTokenOutOfArgv(t *testing.T) {
	cfg, _ := testConfig(t)
	runner := &recordingExecutor{}
	repo := repository{Owner: "Alpha", Name: "Widget"}
	err := executeSelected(cfg, selection{Credential: "alpha", Repository: &repo}, "tool", []string{"safe"}, []string{"PATH=/bin"}, runner)
	if err != nil {
		t.Fatal(err)
	}
	call := runner.calls[0]
	if slices.Contains(call.args, alphaTestToken) {
		t.Fatal("token appeared in argv")
	}
	if token, _ := envValue(call.env, "GH_TOKEN"); token != alphaTestToken {
		t.Fatalf("GH_TOKEN = %q", token)
	}
}

func TestDoctorDiagnosticsNeverContainToken(t *testing.T) {
	cfg, _ := testConfig(t)
	credential := cfg.Credentials["beta"]
	if err := os.WriteFile(credential.TokenFile, nil, 0600); err != nil {
		t.Fatal(err)
	}
	err := runDoctor(cfg)
	if err == nil {
		t.Fatal("runDoctor() succeeded with empty token")
	}
	for _, secret := range []string{alphaTestToken, betaTestToken, projectsTestToken} {
		if strings.Contains(err.Error(), secret) {
			t.Fatalf("diagnostic contains token %q", secret)
		}
	}
}

func TestDoctorValidatesExecutablesAndFiles(t *testing.T) {
	cfg, _ := testConfig(t)
	cfg.Executables.GH = testGitExecutable(t, t.TempDir(), "unused")
	if err := runDoctor(cfg); err != nil {
		t.Fatalf("runDoctor() error = %v", err)
	}
	cfg.AllowedGitConfigs = []string{filepath.Join(t.TempDir(), "missing")}
	if err := runDoctor(cfg); err == nil {
		t.Fatal("runDoctor() succeeded with missing gitconfig")
	}
}

func TestExecutorFailureIsReturned(t *testing.T) {
	cfg, _ := testConfig(t)
	want := errors.New("exec failed")
	runner := &recordingExecutor{err: want}
	err := executeSelected(cfg, selection{Credential: "alpha"}, "tool", nil, os.Environ(), runner)
	if !errors.Is(err, want) {
		t.Fatalf("executeSelected() error = %v", err)
	}
}

func TestSystemExecutorPreservesChildExitAndSignal(t *testing.T) {
	for _, test := range []struct {
		name     string
		mode     string
		exitCode int
		signal   syscall.Signal
	}{
		{name: "exit code", mode: "exit", exitCode: 23},
		{name: "signal", mode: "signal", signal: syscall.SIGTERM},
	} {
		t.Run(test.name, func(t *testing.T) {
			command := exec.Command(os.Args[0], "-test.run=^TestSystemExecutorHelper$")
			command.Env = append(os.Environ(), "AGENT_GITHUB_ROUTER_EXEC_HELPER="+test.mode)
			err := command.Run()
			exitError, ok := err.(*exec.ExitError)
			if !ok {
				t.Fatalf("helper error = %T %v", err, err)
			}
			status, ok := exitError.Sys().(syscall.WaitStatus)
			if !ok {
				t.Fatalf("process status = %T", exitError.Sys())
			}
			if test.signal != 0 {
				if !status.Signaled() || status.Signal() != test.signal {
					t.Fatalf("signal status = %v", status)
				}
			} else if status.ExitStatus() != test.exitCode {
				t.Fatalf("exit status = %d, want %d", status.ExitStatus(), test.exitCode)
			}
		})
	}
}

func TestSystemExecutorHelper(t *testing.T) {
	switch os.Getenv("AGENT_GITHUB_ROUTER_EXEC_HELPER") {
	case "exit":
		if err := (systemExecutor{}).Exec("sh", []string{"-c", "exit 23"}, os.Environ()); err != nil {
			t.Fatal(err)
		}
	case "signal":
		if err := (systemExecutor{}).Exec("sh", []string{"-c", "kill -TERM $$"}, os.Environ()); err != nil {
			t.Fatal(err)
		}
	}
}
