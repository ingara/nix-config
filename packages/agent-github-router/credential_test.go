package main

import (
	"bytes"
	"fmt"
	"os"
	"strings"
	"testing"
)

func TestCredentialGetRoutesCaseInsensitively(t *testing.T) {
	cfg, _ := testConfig(t)
	input := strings.NewReader("protocol=https\nhost=GITHUB.COM\npath=aLpHa/repo.git\n\n")
	var stdout, stderr bytes.Buffer
	code := runCredential(cfg, []string{"get"}, input, &stdout, &stderr)
	if code != 0 || stderr.Len() != 0 {
		t.Fatalf("runCredential() = %d, stderr %q", code, stderr.String())
	}
	want := "username=x-access-token\npassword=" + alphaTestToken + "\n\n"
	if stdout.String() != want {
		t.Fatalf("output = %q, want %q", stdout.String(), want)
	}
}

func TestCredentialGetFailsClosedForRecognizedGitHubRequest(t *testing.T) {
	cfg, _ := testConfig(t)
	for name, path := range map[string]string{
		"missing owner": "unknown/repo",
		"missing path":  "",
	} {
		t.Run(name, func(t *testing.T) {
			input := strings.NewReader(fmt.Sprintf("protocol=https\nhost=github.com\npath=%s\n\n", path))
			var stdout bytes.Buffer
			if code := runCredential(cfg, []string{"get"}, input, &stdout, &bytes.Buffer{}); code != 0 {
				t.Fatalf("runCredential() = %d", code)
			}
			if stdout.String() != "quit=true\n\n" {
				t.Fatalf("output = %q", stdout.String())
			}
		})
	}

	credential := cfg.Credentials["alpha"]
	if err := os.WriteFile(credential.TokenFile, nil, 0600); err != nil {
		t.Fatal(err)
	}
	var stdout bytes.Buffer
	input := strings.NewReader("protocol=https\nhost=github.com\npath=alpha/repo\n\n")
	runCredential(cfg, []string{"get"}, input, &stdout, &bytes.Buffer{})
	if stdout.String() != "quit=true\n\n" {
		t.Fatalf("empty token output = %q", stdout.String())
	}
}

func TestCredentialGetIgnoresUnrelatedProtocolsAndHosts(t *testing.T) {
	cfg, _ := testConfig(t)
	for _, request := range []string{
		"protocol=http\nhost=github.com\npath=alpha/repo\n\n",
		"protocol=https\nhost=example.com\npath=alpha/repo\n\n",
	} {
		var stdout bytes.Buffer
		runCredential(cfg, []string{"get"}, strings.NewReader(request), &stdout, &bytes.Buffer{})
		if stdout.Len() != 0 {
			t.Fatalf("unrelated request output = %q", stdout.String())
		}
	}
}

func TestCredentialStoreAndEraseAreNoOps(t *testing.T) {
	cfg, _ := testConfig(t)
	for _, operation := range []string{"store", "erase"} {
		var stdout, stderr bytes.Buffer
		if code := runCredential(cfg, []string{operation}, strings.NewReader("password=must-not-be-stored\n"), &stdout, &stderr); code != 0 {
			t.Fatalf("%s code = %d", operation, code)
		}
		if stdout.Len() != 0 || stderr.Len() != 0 {
			t.Fatalf("%s produced output", operation)
		}
	}
}
