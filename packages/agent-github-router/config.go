package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

type config struct {
	Version              int                   `json:"version"`
	Executables          executables           `json:"executables"`
	GHConfigDir          string                `json:"ghConfigDir"`
	AllowedGitConfigs    []string              `json:"allowedGitConfigs"`
	Credentials          map[string]credential `json:"credentials"`
	OwnerRoutes          map[string]string     `json:"ownerRoutes"`
	ProjectsCredential   *string               `json:"projectsCredential"`
	routesByLoweredOwner map[string]string
}

type executables struct {
	GH  string `json:"gh"`
	Git string `json:"git"`
}

type credential struct {
	TokenFile string `json:"tokenFile"`
}

func loadConfig(path string) (config, error) {
	f, err := os.Open(path)
	if err != nil {
		return config{}, fmt.Errorf("open config: %w", err)
	}
	defer f.Close()

	decoder := json.NewDecoder(f)
	decoder.DisallowUnknownFields()
	var cfg config
	if err := decoder.Decode(&cfg); err != nil {
		return config{}, fmt.Errorf("decode config: %w", err)
	}
	if err := ensureJSONEOF(decoder); err != nil {
		return config{}, err
	}
	if err := cfg.validate(); err != nil {
		return config{}, err
	}
	return cfg, nil
}

func ensureJSONEOF(decoder *json.Decoder) error {
	var extra any
	if err := decoder.Decode(&extra); err != io.EOF {
		if err == nil {
			return fmt.Errorf("decode config: multiple JSON values")
		}
		return fmt.Errorf("decode config: %w", err)
	}
	return nil
}

func (cfg *config) validate() error {
	if cfg.Version != 1 {
		return fmt.Errorf("config: unsupported version %d", cfg.Version)
	}
	if cfg.Executables.GH == "" || cfg.Executables.Git == "" {
		return fmt.Errorf("config: executables.gh and executables.git are required")
	}
	if cfg.GHConfigDir == "" {
		return fmt.Errorf("config: ghConfigDir is required")
	}
	for _, path := range cfg.AllowedGitConfigs {
		if path == "" {
			return fmt.Errorf("config: allowedGitConfigs contains an empty path")
		}
	}
	if len(cfg.Credentials) == 0 {
		return fmt.Errorf("config: credentials must not be empty")
	}
	for name, credential := range cfg.Credentials {
		if name == "" || credential.TokenFile == "" {
			return fmt.Errorf("config: credential names and tokenFile values must not be empty")
		}
	}
	if cfg.ProjectsCredential != nil {
		if *cfg.ProjectsCredential == "" {
			return fmt.Errorf("config: projectsCredential must be null or a credential name")
		}
		if _, ok := cfg.Credentials[*cfg.ProjectsCredential]; !ok {
			return fmt.Errorf("config: projectsCredential %q is not defined", *cfg.ProjectsCredential)
		}
	}

	cfg.routesByLoweredOwner = make(map[string]string, len(cfg.OwnerRoutes))
	owners := make([]string, 0, len(cfg.OwnerRoutes))
	for owner := range cfg.OwnerRoutes {
		owners = append(owners, owner)
	}
	sort.Strings(owners)
	ownersByLoweredName := make(map[string]string, len(owners))
	for _, owner := range owners {
		credentialName := cfg.OwnerRoutes[owner]
		if owner == "" {
			return fmt.Errorf("config: ownerRoutes contains an empty owner")
		}
		if !validRepositoryPart(owner) {
			return fmt.Errorf("config: owner route %q is not an owner", owner)
		}
		if _, ok := cfg.Credentials[credentialName]; !ok {
			return fmt.Errorf("config: owner route %q names unknown credential %q", owner, credentialName)
		}
		lowered := strings.ToLower(owner)
		if previous, exists := ownersByLoweredName[lowered]; exists {
			return fmt.Errorf("config: owner routes %q and %q collide case-insensitively", previous, owner)
		}
		ownersByLoweredName[lowered] = owner
		cfg.routesByLoweredOwner[lowered] = credentialName
	}
	return nil
}

// servableOwners lists the owners this router holds a credential for, as
// configured and in a stable order. Names only — never a credential name or a
// token path, since this feeds a user-facing message.
func (cfg config) servableOwners() []string {
	owners := make([]string, 0, len(cfg.OwnerRoutes))
	for owner := range cfg.OwnerRoutes {
		owners = append(owners, owner)
	}
	sort.Strings(owners)
	return owners
}

func (cfg config) credentialForOwner(owner string) (string, bool) {
	name, ok := cfg.routesByLoweredOwner[strings.ToLower(owner)]
	return name, ok
}

func (cfg config) tokenForCredential(name string) (string, error) {
	credential, ok := cfg.Credentials[name]
	if !ok {
		return "", fmt.Errorf("unknown credential %q", name)
	}
	contents, err := os.ReadFile(credential.TokenFile)
	if err != nil {
		return "", fmt.Errorf("read credential %q: %w", name, err)
	}
	token := strings.TrimRight(string(contents), "\r\n")
	if token == "" {
		return "", fmt.Errorf("credential %q is empty", name)
	}
	if strings.ContainsAny(token, "\r\n") {
		return "", fmt.Errorf("credential %q contains multiple lines", name)
	}
	if err := validateGitHubPATShape(token); err != nil {
		return "", fmt.Errorf("credential %q has invalid GitHub PAT shape: %w", name, err)
	}
	return token, nil
}

func validateGitHubPATShape(token string) error {
	// Token lengths can change, so validate only the PAT prefix and character set.
	payload, found := strings.CutPrefix(token, "ghp_")
	if !found {
		payload, found = strings.CutPrefix(token, "github_pat_")
	}
	if !found {
		return fmt.Errorf("expected a personal access token")
	}
	if payload == "" {
		return fmt.Errorf("personal access token payload is empty")
	}
	for _, character := range token {
		if character != '_' && (character < '0' || character > '9') &&
			(character < 'A' || character > 'Z') && (character < 'a' || character > 'z') {
			return fmt.Errorf("contains a non-ASCII token character")
		}
	}
	return nil
}

func (cfg config) validateAgentGitConfig(value string) error {
	for _, allowed := range cfg.AllowedGitConfigs {
		if value == allowed {
			return nil
		}
	}

	resolvedValue, err := filepath.EvalSymlinks(value)
	if err != nil {
		return fmt.Errorf("unrecognized agent gitconfig")
	}
	for _, allowed := range cfg.AllowedGitConfigs {
		resolvedAllowed, err := filepath.EvalSymlinks(allowed)
		if err == nil && resolvedValue == resolvedAllowed {
			return nil
		}
	}
	return fmt.Errorf("unrecognized agent gitconfig")
}
