package main

import "testing"

func TestParseRepositoryForms(t *testing.T) {
	tests := map[string]string{
		"Owner/Repo":                          "owner/repo",
		"github.com/Owner/Repo":               "owner/repo",
		"https://github.com/Owner/Repo.git":   "owner/repo",
		"ssh://git@github.com/Owner/Repo.git": "owner/repo",
		"git@github.com:Owner/Repo.git":       "owner/repo",
	}
	for input, want := range tests {
		t.Run(input, func(t *testing.T) {
			repo, err := parseRepository(input)
			if err != nil {
				t.Fatalf("parseRepository() error = %v", err)
			}
			if got := repo.String(); got != want {
				t.Fatalf("parseRepository() = %q, want %q", got, want)
			}
		})
	}
}

func TestParseRepositoryRejectsUnsupportedTargets(t *testing.T) {
	for _, input := range []string{
		"owner", "owner/repo/extra", "https://gitlab.com/owner/repo",
		"http://github.com/owner/repo", "github.com:443/owner/repo",
		"{owner}/{repo}", "owner/re po",
	} {
		t.Run(input, func(t *testing.T) {
			if _, err := parseRepository(input); err == nil {
				t.Fatalf("parseRepository(%q) succeeded", input)
			}
		})
	}
}

func TestRepositoryFromAPIEndpoint(t *testing.T) {
	repo, matched, err := repositoryFromAPIEndpoint("repos/Alpha/Widget/issues/1")
	if err != nil || !matched || repo.String() != "alpha/widget" {
		t.Fatalf("repositoryFromAPIEndpoint() = %#v, %v, %v", repo, matched, err)
	}
	if _, matched, err := repositoryFromAPIEndpoint("graphql"); err != nil || matched {
		t.Fatalf("generic endpoint matched: %v, %v", matched, err)
	}
}
