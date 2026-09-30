package main

import (
	"fmt"
	"os"
	"os/exec"
	"sort"
	"strings"
	"syscall"
)

var scrubbedVariables = []string{
	"GH_TOKEN",
	"GITHUB_TOKEN",
	"GH_ENTERPRISE_TOKEN",
	"GITHUB_ENTERPRISE_TOKEN",
	"GH_CONFIG_DIR",
	"GH_HOST",
	"GH_REPO",
}

type executor interface {
	Exec(command string, args []string, environment []string) error
}

type systemExecutor struct{}

func (systemExecutor) Exec(command string, args []string, environment []string) error {
	path, err := exec.LookPath(command)
	if err != nil {
		return err
	}
	return syscall.Exec(path, append([]string{command}, args...), environment)
}

func controlledEnvironment(base []string, cfg config, token string, repo *repository) []string {
	values := controlledEnvironmentValues(base, cfg)
	values["GH_TOKEN"] = token
	if repo != nil {
		values["GH_REPO"] = repo.String()
	}
	return flattenEnvironment(values)
}

func tokenlessEnvironment(base []string, cfg config) []string {
	return flattenEnvironment(controlledEnvironmentValues(base, cfg))
}

func controlledEnvironmentValues(base []string, cfg config) map[string]string {
	values := make(map[string]string, len(base)+4)
	for _, item := range base {
		key, value, ok := strings.Cut(item, "=")
		if ok {
			values[key] = value
		}
	}
	for _, key := range scrubbedVariables {
		delete(values, key)
	}
	values["GH_CONFIG_DIR"] = cfg.GHConfigDir
	values["GH_HOST"] = "github.com"
	return values
}

func flattenEnvironment(values map[string]string) []string {
	keys := make([]string, 0, len(values))
	for key := range values {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	environment := make([]string, 0, len(keys))
	for _, key := range keys {
		environment = append(environment, key+"="+values[key])
	}
	return environment
}

func executeSelected(cfg config, selected selection, command string, args []string, baseEnv []string, runner executor) error {
	token, err := cfg.tokenForCredential(selected.Credential)
	if err != nil {
		return err
	}
	return runner.Exec(command, args, controlledEnvironment(baseEnv, cfg, token, selected.Repository))
}

func lookupEnv(environment []string, key string) (string, bool) {
	for i := len(environment) - 1; i >= 0; i-- {
		candidate, value, ok := strings.Cut(environment[i], "=")
		if ok && candidate == key {
			return value, true
		}
	}
	return "", false
}

func originRepository(cfg config, environment []string) (repository, error) {
	command := exec.Command(cfg.Executables.Git, "remote", "get-url", "origin")
	command.Env = environment
	output, err := command.Output()
	if err != nil {
		return repository{}, fmt.Errorf("cannot determine origin repository")
	}
	repo, err := parseRepository(strings.TrimSpace(string(output)))
	if err != nil {
		return repository{}, fmt.Errorf("origin is not a supported GitHub repository")
	}
	return repo, nil
}

func runDoctor(cfg config) error {
	for name, executable := range map[string]string{"gh": cfg.Executables.GH, "git": cfg.Executables.Git} {
		path, err := exec.LookPath(executable)
		if err != nil {
			return fmt.Errorf("%s executable is unavailable", name)
		}
		info, err := os.Stat(path)
		if err != nil || info.IsDir() || info.Mode()&0111 == 0 {
			return fmt.Errorf("%s executable is not executable", name)
		}
	}
	info, err := os.Stat(cfg.GHConfigDir)
	if err != nil || !info.IsDir() {
		return fmt.Errorf("ghConfigDir is not a readable directory")
	}
	dir, err := os.Open(cfg.GHConfigDir)
	if err != nil {
		return fmt.Errorf("ghConfigDir is not a readable directory")
	}
	dir.Close()
	for _, path := range cfg.AllowedGitConfigs {
		info, err := os.Stat(path)
		if err != nil || !info.Mode().IsRegular() {
			return fmt.Errorf("an allowed gitconfig is not readable")
		}
		file, err := os.Open(path)
		if err != nil {
			return fmt.Errorf("an allowed gitconfig is not readable")
		}
		file.Close()
	}
	for name := range cfg.Credentials {
		if _, err := cfg.tokenForCredential(name); err != nil {
			return err
		}
	}
	return nil
}
