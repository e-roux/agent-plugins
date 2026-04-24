package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

type PushOptions struct {
	Remote string
	Branch string
	Force  bool
}

type PRCreateOptions struct {
	Title        string
	Body         string
	SourceBranch string
	TargetBranch string
	Draft        bool
}

type PRMergeOptions struct {
	Identifier    string
	DeleteBranch  bool
	MergeStrategy string
}

type PRStatusOptions struct {
	Identifier string
	Branch     string
}

type CommandResult struct {
	Success bool
	Output  string
	URL     string
}

type PRInfo struct {
	Identifier string
	Title      string
	State      string
	URL        string
	Source     string
	Target     string
}

type Platform interface {
	PlatformName() string
	Push(ctx context.Context, opts PushOptions) (*CommandResult, error)
	CreatePR(ctx context.Context, opts PRCreateOptions) (*CommandResult, error)
	MergePR(ctx context.Context, opts PRMergeOptions) (*CommandResult, error)
	PRStatus(ctx context.Context, opts PRStatusOptions) (*PRInfo, error)
}

var protectedBranches = parseProtectedBranches()

func parseProtectedBranches() []string {
	env := os.Getenv("PROTECTED_BRANCHES")
	if env == "" {
		return []string{"main", "master"}
	}
	parts := strings.Split(env, ",")
	result := make([]string, 0, len(parts))
	for _, b := range parts {
		trimmed := strings.TrimSpace(b)
		if trimmed != "" {
			result = append(result, trimmed)
		}
	}
	return result
}

func isProtectedBranch(branch string) bool {
	for _, protected := range protectedBranches {
		if branch == protected {
			return true
		}
	}
	return false
}

func detectPlatform() (Platform, error) {
	if override := os.Getenv("GIT_OPS_PLATFORM"); override != "" {
		switch strings.ToLower(override) {
		case "github":
			return &GitHubPlatform{}, nil
		case "gitlab":
			return &GitLabPlatform{}, nil
		case "azuredevops", "azure":
			return &AzureDevOpsPlatform{}, nil
		default:
			return nil, fmt.Errorf("unknown platform override: %s", override)
		}
	}

	remoteURL, err := runGitCommand("remote", "get-url", "origin")
	if err != nil {
		return nil, fmt.Errorf("cannot read git remote: %w", err)
	}

	lowered := strings.ToLower(remoteURL)

	if strings.Contains(lowered, "github.com") {
		return &GitHubPlatform{}, nil
	}
	if strings.Contains(lowered, "gitlab") {
		return &GitLabPlatform{}, nil
	}
	if strings.Contains(lowered, "dev.azure.com") || strings.Contains(lowered, "visualstudio.com") {
		return &AzureDevOpsPlatform{}, nil
	}

	if cliAvailable("gh") {
		return &GitHubPlatform{}, nil
	}
	if cliAvailable("glab") {
		return &GitLabPlatform{}, nil
	}
	if cliAvailable("az") {
		return &AzureDevOpsPlatform{}, nil
	}

	return nil, fmt.Errorf("cannot detect platform from remote: %s", remoteURL)
}

func currentBranch() (string, error) {
	return runGitCommand("rev-parse", "--abbrev-ref", "HEAD")
}

func runGitCommand(args ...string) (string, error) {
	out, err := exec.Command("git", args...).CombinedOutput()
	if err != nil {
		return strings.TrimSpace(string(out)), fmt.Errorf("%s: %w", strings.TrimSpace(string(out)), err)
	}
	return strings.TrimSpace(string(out)), nil
}

func runExternalCommand(name string, args ...string) (string, error) {
	out, err := exec.Command(name, args...).CombinedOutput()
	if err != nil {
		return strings.TrimSpace(string(out)), fmt.Errorf("%s: %w", strings.TrimSpace(string(out)), err)
	}
	return strings.TrimSpace(string(out)), nil
}

func cliAvailable(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}

func extractURL(output string) string {
	for _, line := range strings.Split(output, "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "https://") {
			return trimmed
		}
	}
	return ""
}

func boolFlag(b bool) string {
	if b {
		return "true"
	}
	return "false"
}
