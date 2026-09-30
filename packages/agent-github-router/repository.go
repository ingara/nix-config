package main

import (
	"fmt"
	"net/url"
	"strings"
)

type repository struct {
	Owner string
	Name  string
}

func (repo repository) String() string {
	return strings.ToLower(repo.Owner + "/" + repo.Name)
}

func parseRepository(value string) (repository, error) {
	value = strings.TrimSpace(value)
	if value == "" {
		return repository{}, fmt.Errorf("empty repository")
	}

	var path string
	switch {
	case strings.HasPrefix(value, "git@"):
		hostAndPath := strings.TrimPrefix(value, "git@")
		host, rest, ok := strings.Cut(hostAndPath, ":")
		if !ok || !strings.EqualFold(host, "github.com") {
			return repository{}, fmt.Errorf("repository host must be github.com")
		}
		path = rest
	case strings.Contains(value, "://"):
		parsed, err := url.Parse(value)
		if err != nil || parsed.Hostname() == "" {
			return repository{}, fmt.Errorf("invalid repository URL")
		}
		if !strings.EqualFold(parsed.Hostname(), "github.com") || parsed.Port() != "" {
			return repository{}, fmt.Errorf("repository host must be github.com")
		}
		if parsed.Scheme != "https" && parsed.Scheme != "ssh" {
			return repository{}, fmt.Errorf("repository URL must use https or ssh")
		}
		path = parsed.Path
	case strings.HasPrefix(strings.ToLower(value), "github.com/"):
		path = value[len("github.com/"):]
	default:
		path = value
	}

	path = strings.Trim(path, "/")
	path = strings.TrimSuffix(path, ".git")
	parts := strings.Split(path, "/")
	if len(parts) != 2 || !validRepositoryPart(parts[0]) || !validRepositoryPart(parts[1]) {
		return repository{}, fmt.Errorf("repository must be OWNER/REPO")
	}
	return repository{Owner: parts[0], Name: parts[1]}, nil
}

func validRepositoryPart(value string) bool {
	if value == "" || value == "." || value == ".." || strings.ContainsAny(value, "{}\t\r\n ") {
		return false
	}
	for _, r := range value {
		if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') || r == '-' || r == '_' || r == '.' {
			continue
		}
		return false
	}
	return true
}

func repositoryFromAPIEndpoint(endpoint string) (repository, bool, error) {
	endpoint = strings.TrimPrefix(endpoint, "/")
	parts := strings.Split(endpoint, "/")
	if len(parts) < 3 || parts[0] != "repos" {
		return repository{}, false, nil
	}
	if parts[1] == "{owner}" || parts[2] == "{repo}" {
		return repository{}, false, nil
	}
	repo, err := parseRepository(parts[1] + "/" + parts[2])
	if err != nil {
		return repository{}, true, fmt.Errorf("invalid API repository target: %w", err)
	}
	return repo, true, nil
}
