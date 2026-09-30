package main

import (
	"bufio"
	"errors"
	"fmt"
	"io"
	"os"
	"strings"
)

const (
	exitFailure = 1
	exitUsage   = 2
	exitPolicy  = 4
)

type selection struct {
	Credential string
	Repository *repository
}

func main() {
	os.Exit(run(os.Args[1:], os.Stdin, os.Stdout, os.Stderr, os.Environ(), systemExecutor{}))
}

func run(args []string, stdin io.Reader, stdout, stderr io.Writer, environment []string, runner executor) int {
	if len(args) < 3 || args[0] != "--config" || args[1] == "" {
		fmt.Fprintln(stderr, "usage: agent-github-router --config FILE <credential|gh|exec|doctor>")
		return exitUsage
	}
	cfg, err := loadConfig(args[1])
	if err != nil {
		fmt.Fprintf(stderr, "agent-github-router: %v\n", err)
		return exitUsage
	}

	switch args[2] {
	case "credential":
		return runCredential(cfg, args[3:], stdin, stdout, stderr)
	case "gh":
		return runGH(cfg, args[3:], stderr, environment, runner)
	case "exec":
		return runExplicitExec(cfg, args[3:], stderr, environment, runner)
	case "doctor":
		if len(args) != 3 {
			fmt.Fprintln(stderr, "agent-github-router: doctor takes no arguments")
			return exitUsage
		}
		if err := runDoctor(cfg); err != nil {
			fmt.Fprintf(stderr, "agent-github-router: doctor: %v\n", err)
			return exitFailure
		}
		fmt.Fprintln(stdout, "agent-github-router: configuration is valid")
		return 0
	default:
		fmt.Fprintf(stderr, "agent-github-router: unknown command %q\n", args[2])
		return exitUsage
	}
}

func runCredential(cfg config, args []string, stdin io.Reader, stdout, stderr io.Writer) int {
	if len(args) != 1 {
		fmt.Fprintln(stderr, "agent-github-router: credential requires get, store, or erase")
		return exitUsage
	}
	if args[0] == "store" || args[0] == "erase" {
		return 0
	}
	if args[0] != "get" {
		fmt.Fprintln(stderr, "agent-github-router: credential requires get, store, or erase")
		return exitUsage
	}

	request, err := readCredentialRequest(stdin)
	if err != nil {
		fmt.Fprintf(stderr, "agent-github-router: credential request: %v\n", err)
		return exitFailure
	}
	if !strings.EqualFold(request["protocol"], "https") || !strings.EqualFold(request["host"], "github.com") {
		return 0
	}
	repo, err := parseRepository(request["path"])
	if err != nil {
		fmt.Fprint(stdout, "quit=true\n\n")
		return 0
	}
	credentialName, ok := cfg.credentialForOwner(repo.Owner)
	if !ok {
		fmt.Fprint(stdout, "quit=true\n\n")
		return 0
	}
	token, err := cfg.tokenForCredential(credentialName)
	if err != nil {
		fmt.Fprint(stdout, "quit=true\n\n")
		return 0
	}
	fmt.Fprintf(stdout, "username=x-access-token\npassword=%s\n\n", token)
	return 0
}

func readCredentialRequest(input io.Reader) (map[string]string, error) {
	request := make(map[string]string)
	scanner := bufio.NewScanner(input)
	scanner.Buffer(make([]byte, 1024), 1024*1024)
	for scanner.Scan() {
		line := scanner.Text()
		if line == "" {
			break
		}
		key, value, ok := strings.Cut(line, "=")
		if ok {
			request[key] = value
		}
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}
	return request, nil
}

func runGH(cfg config, args []string, stderr io.Writer, environment []string, runner executor) int {
	if len(args) == 0 || args[0] != "--" {
		fmt.Fprintln(stderr, "agent-github-router: gh requires -- before gh arguments")
		return exitUsage
	}
	ghArgs := args[1:]
	gitConfig, _ := lookupEnv(environment, "GIT_CONFIG_GLOBAL")
	if err := cfg.validateAgentGitConfig(gitConfig); err != nil {
		fmt.Fprintf(stderr, "agent-github-router: %v; refusing credential fallback\n", err)
		return exitPolicy
	}
	command, commandIndex := ghCommand(ghArgs)
	if isAuthInvocation(ghArgs, command, commandIndex) {
		fmt.Fprintf(stderr, "agent-github-router: %s\n", authRefusalMessage(cfg))
		return exitPolicy
	}
	if isTokenlessGHInvocation(ghArgs, command) {
		if err := validateHostnameArguments(ghArgs); err != nil {
			fmt.Fprintf(stderr, "agent-github-router: %v\n", err)
			return exitPolicy
		}
		if err := runner.Exec(cfg.Executables.GH, ghArgs, tokenlessEnvironment(environment, cfg)); err != nil {
			fmt.Fprintf(stderr, "agent-github-router: execute gh: %v\n", err)
			return exitFailure
		}
		return 0
	}

	selected, err := selectGHCredential(cfg, ghArgs, environment)
	if err != nil {
		fmt.Fprintf(stderr, "agent-github-router: %v\n", err)
		return exitPolicy
	}
	if err := executeSelected(cfg, selected, cfg.Executables.GH, ghArgs, environment, runner); err != nil {
		fmt.Fprintf(stderr, "agent-github-router: execute gh: %v\n", err)
		return exitFailure
	}
	return 0
}

func selectGHCredential(cfg config, args, environment []string) (selection, error) {
	if host, ok := lookupEnv(environment, "GH_HOST"); ok && host != "" && !strings.EqualFold(host, "github.com") {
		return selection{}, fmt.Errorf("only github.com is supported")
	}
	if err := validateHostnameArguments(args); err != nil {
		return selection{}, err
	}
	command, commandIndex := ghCommand(args)
	if isAuthInvocation(args, command, commandIndex) {
		return selection{}, errors.New(authRefusalMessage(cfg))
	}
	if command == "project" {
		if cfg.ProjectsCredential == nil {
			return selection{}, fmt.Errorf("no Projects credential is configured")
		}
		return selection{Credential: *cfg.ProjectsCredential}, nil
	}

	direct, err := directRepositoryTarget(args, command, commandIndex)
	if err != nil {
		return selection{}, err
	}
	var repo repository
	if direct != nil {
		repo = *direct
	} else if value, ok := lookupEnv(environment, "GH_REPO"); ok && value != "" {
		repo, err = parseRepository(value)
		if err != nil {
			return selection{}, fmt.Errorf("invalid GH_REPO: %w", err)
		}
	} else {
		repo, err = originRepository(cfg, environment)
		if err != nil {
			return selection{}, fmt.Errorf("no unambiguous repository target: %w", err)
		}
	}
	credentialName, ok := cfg.credentialForOwner(repo.Owner)
	if !ok {
		return selection{}, fmt.Errorf("no credential route for repository owner %q", repo.Owner)
	}
	return selection{Credential: credentialName, Repository: &repo}, nil
}

// authRefusalMessage keeps refusing `gh auth`, but says how to answer the
// question the caller was asking. `gh auth status` reports on a logged-in
// account; this identity has none, so the equivalent check is per repository.
func authRefusalMessage(cfg config) string {
	const refusal = "gh auth commands are unavailable"
	owners := cfg.servableOwners()
	if len(owners) == 0 {
		return refusal + "; no repository owners are configured for this identity"
	}
	return fmt.Sprintf(
		"%s; check access per repository with `gh repo view <owner>/<repo> --json name` (owners: %s)",
		refusal,
		strings.Join(owners, ", "),
	)
}

func isAuthInvocation(args []string, command string, commandIndex int) bool {
	if command == "auth" {
		return true
	}
	if command != "help" || commandIndex < 0 {
		return false
	}
	for _, arg := range args[commandIndex+1:] {
		if arg == "--" {
			break
		}
		if strings.HasPrefix(arg, "-") {
			continue
		}
		return arg == "auth"
	}
	return false
}

func isTokenlessGHInvocation(args []string, command string) bool {
	if len(args) == 0 || command == "" {
		return true
	}
	if command == "help" || command == "version" || command == "completion" || command == "config" {
		return true
	}
	for _, arg := range args {
		if arg == "--" {
			break
		}
		if arg == "--help" {
			return true
		}
	}
	return false
}

func validateHostnameArguments(args []string) error {
	for i := 0; i < len(args); i++ {
		if args[i] == "--" {
			break
		}
		switch {
		case args[i] == "--hostname":
			if i+1 >= len(args) {
				return fmt.Errorf("--hostname requires a value")
			}
			i++
			if !strings.EqualFold(args[i], "github.com") {
				return fmt.Errorf("only github.com is supported")
			}
		case strings.HasPrefix(args[i], "--hostname="):
			if !strings.EqualFold(strings.TrimPrefix(args[i], "--hostname="), "github.com") {
				return fmt.Errorf("only github.com is supported")
			}
		}
	}
	return nil
}

func ghCommand(args []string) (string, int) {
	skipNext := false
	for i, arg := range args {
		if arg == "--" {
			break
		}
		if skipNext {
			skipNext = false
			continue
		}
		if arg == "-R" || arg == "--repo" || arg == "--hostname" {
			skipNext = true
			continue
		}
		if strings.HasPrefix(arg, "-") {
			continue
		}
		return arg, i
	}
	return "", -1
}

func directRepositoryTarget(args []string, command string, commandIndex int) (*repository, error) {
	var targets []repository
	for i := 0; i < len(args); i++ {
		arg := args[i]
		if arg == "--" {
			break
		}
		var value string
		switch {
		case arg == "-R" || arg == "--repo":
			if i+1 >= len(args) || args[i+1] == "--" {
				return nil, fmt.Errorf("%s requires a repository", arg)
			}
			i++
			value = args[i]
		case strings.HasPrefix(arg, "--repo="):
			value = strings.TrimPrefix(arg, "--repo=")
		case strings.HasPrefix(arg, "-R="):
			value = strings.TrimPrefix(arg, "-R=")
		case strings.HasPrefix(arg, "-R"):
			value = strings.TrimPrefix(arg, "-R")
		}
		if (arg == "-R" || arg == "--repo" || strings.HasPrefix(arg, "--repo=") || strings.HasPrefix(arg, "-R=")) && value == "" {
			return nil, fmt.Errorf("%s requires a repository", arg)
		}
		if value != "" {
			repo, err := parseRepository(value)
			if err != nil {
				return nil, fmt.Errorf("invalid explicit repository target: %w", err)
			}
			targets = append(targets, repo)
		}
	}

	if repo, ok, err := positionalRepositoryTarget(args, command, commandIndex); err != nil {
		return nil, err
	} else if ok {
		targets = append(targets, repo)
	}
	if command == "api" {
		endpoint, ok, err := firstPositionalArgument(args, commandIndex+1, isAPIRepositoryTarget)
		if err != nil {
			return nil, err
		}
		if ok {
			if repo, found, err := repositoryFromAPIEndpoint(endpoint); err != nil {
				return nil, err
			} else if found {
				targets = append(targets, repo)
			}
		}
	}

	if len(targets) == 0 {
		return nil, nil
	}
	first := targets[0]
	for _, target := range targets[1:] {
		if !strings.EqualFold(first.String(), target.String()) {
			return nil, fmt.Errorf("conflicting repository targets")
		}
	}
	return &first, nil
}

func positionalRepositoryTarget(args []string, command string, commandIndex int) (repository, bool, error) {
	if command != "repo" || commandIndex < 0 || commandIndex+2 >= len(args) {
		return repository{}, false, nil
	}
	subcommand := args[commandIndex+1]
	if strings.HasPrefix(subcommand, "-") {
		return repository{}, false, nil
	}
	takesRepository := map[string]bool{
		"archive": true, "clone": true, "create": true, "delete": true,
		"edit": true, "fork": true, "set-default": true, "sync": true,
		"unarchive": true, "view": true,
	}
	if !takesRepository[subcommand] {
		return repository{}, false, nil
	}
	candidate, ok, err := firstPositionalArgument(args, commandIndex+2, isRepositoryTarget)
	if err != nil {
		return repository{}, false, err
	}
	if !ok {
		return repository{}, false, nil
	}
	repo, err := parseRepository(candidate)
	if err != nil {
		return repository{}, true, fmt.Errorf("invalid repository positional target: %w", err)
	}
	return repo, true, nil
}

func firstPositionalArgument(args []string, start int, targetLike func(string) bool) (string, bool, error) {
	for i := start; i < len(args); i++ {
		arg := args[i]
		if arg == "--" {
			break
		}
		if !strings.HasPrefix(arg, "-") {
			return arg, true, nil
		}
		if strings.Contains(arg, "=") || i+1 >= len(args) || strings.HasPrefix(args[i+1], "-") {
			continue
		}
		i++
		if targetLike(args[i]) {
			return "", false, fmt.Errorf("ambiguous repository target %q after %s; put the target before flags or use router exec --repo", args[i], arg)
		}
	}
	return "", false, nil
}

func isRepositoryTarget(value string) bool {
	_, err := parseRepository(value)
	return err == nil
}

func isAPIRepositoryTarget(value string) bool {
	_, ok, err := repositoryFromAPIEndpoint(value)
	return err == nil && ok
}

func runExplicitExec(cfg config, args []string, stderr io.Writer, environment []string, runner executor) int {
	selected, command, commandArgs, err := parseExplicitExec(cfg, args)
	if err != nil {
		fmt.Fprintf(stderr, "agent-github-router: %v\n", err)
		return exitUsage
	}
	if err := executeSelected(cfg, selected, command, commandArgs, environment, runner); err != nil {
		fmt.Fprintf(stderr, "agent-github-router: execute: %v\n", err)
		return exitFailure
	}
	return 0
}

func parseExplicitExec(cfg config, args []string) (selection, string, []string, error) {
	separator := -1
	for i, arg := range args {
		if arg == "--" {
			separator = i
			break
		}
	}
	if separator < 0 || separator == len(args)-1 {
		return selection{}, "", nil, errors.New("exec requires a selector and -- COMMAND")
	}

	var repoValue, credentialName string
	for i := 0; i < separator; i++ {
		switch args[i] {
		case "--repo":
			if repoValue != "" || i+1 >= separator {
				return selection{}, "", nil, errors.New("exec requires exactly one selector")
			}
			i++
			repoValue = args[i]
		case "--credential":
			if credentialName != "" || i+1 >= separator {
				return selection{}, "", nil, errors.New("exec requires exactly one selector")
			}
			i++
			credentialName = args[i]
		default:
			return selection{}, "", nil, fmt.Errorf("unknown exec option %q", args[i])
		}
	}
	if (repoValue == "") == (credentialName == "") {
		return selection{}, "", nil, errors.New("exec requires exactly one of --repo or --credential")
	}

	selected := selection{Credential: credentialName}
	if repoValue != "" {
		repo, err := parseRepository(repoValue)
		if err != nil {
			return selection{}, "", nil, fmt.Errorf("invalid repository: %w", err)
		}
		name, ok := cfg.credentialForOwner(repo.Owner)
		if !ok {
			return selection{}, "", nil, fmt.Errorf("no credential route for repository owner %q", repo.Owner)
		}
		selected.Credential = name
		selected.Repository = &repo
	} else if _, ok := cfg.Credentials[credentialName]; !ok {
		return selection{}, "", nil, fmt.Errorf("unknown credential %q", credentialName)
	}
	return selected, args[separator+1], args[separator+2:], nil
}
