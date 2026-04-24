package main

import (
	"context"
	"fmt"
	"strings"
)

type GitLabPlatform struct{}

func (g *GitLabPlatform) PlatformName() string { return "gitlab" }

func (g *GitLabPlatform) Push(_ context.Context, opts PushOptions) (*CommandResult, error) {
	args := []string{"push", opts.Remote, opts.Branch}
	if opts.Force {
		args = []string{"push", "--force-with-lease", opts.Remote, opts.Branch}
	}
	output, err := runGitCommand(args...)
	if err != nil {
		return &CommandResult{Success: false, Output: output}, err
	}
	return &CommandResult{Success: true, Output: output}, nil
}

func (g *GitLabPlatform) CreatePR(_ context.Context, opts PRCreateOptions) (*CommandResult, error) {
	args := []string{
		"mr", "create",
		"--title", opts.Title,
		"--description", opts.Body,
		"--remove-source-branch",
	}
	if opts.TargetBranch != "" {
		args = append(args, "--target-branch", opts.TargetBranch)
	}
	if opts.SourceBranch != "" {
		args = append(args, "--source-branch", opts.SourceBranch)
	}
	if opts.Draft {
		args = append(args, "--draft")
	}

	output, err := runExternalCommand("glab", args...)
	if err != nil {
		return &CommandResult{Success: false, Output: output}, err
	}
	return &CommandResult{Success: true, Output: output, URL: extractURL(output)}, nil
}

func (g *GitLabPlatform) MergePR(_ context.Context, opts PRMergeOptions) (*CommandResult, error) {
	args := []string{"mr", "merge", opts.Identifier}

	switch strings.ToLower(opts.MergeStrategy) {
	case "squash":
		args = append(args, "--squash")
	case "rebase":
		args = append(args, "--rebase")
	}
	if opts.DeleteBranch {
		args = append(args, "--remove-source-branch")
	}

	output, err := runExternalCommand("glab", args...)
	if err != nil {
		return &CommandResult{Success: false, Output: output}, err
	}
	return &CommandResult{Success: true, Output: output}, nil
}

func (g *GitLabPlatform) PRStatus(_ context.Context, opts PRStatusOptions) (*PRInfo, error) {
	ref := opts.Identifier
	if ref == "" && opts.Branch != "" {
		ref = opts.Branch
	}

	args := []string{"mr", "view"}
	if ref != "" {
		args = append(args, ref)
	}

	output, err := runExternalCommand("glab", args...)
	if err != nil {
		return nil, fmt.Errorf("glab mr view: %s", output)
	}

	return parseGitLabMROutput(output), nil
}

func parseGitLabMROutput(output string) *PRInfo {
	info := &PRInfo{}
	for _, line := range strings.Split(output, "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "title:") {
			info.Title = strings.TrimSpace(strings.TrimPrefix(trimmed, "title:"))
		}
		if strings.HasPrefix(trimmed, "state:") {
			info.State = strings.TrimSpace(strings.TrimPrefix(trimmed, "state:"))
		}
		if strings.HasPrefix(trimmed, "url:") {
			info.URL = strings.TrimSpace(strings.TrimPrefix(trimmed, "url:"))
		}
		if strings.HasPrefix(trimmed, "https://") && info.URL == "" {
			info.URL = trimmed
		}
	}
	return info
}
