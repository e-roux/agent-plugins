package main

import (
	"context"
	"fmt"
	"testing"
)

// --- mock platform ---

type mockPlatform struct {
	name         string
	pushResult   *CommandResult
	pushErr      error
	createResult *CommandResult
	createErr    error
	mergeResult  *CommandResult
	mergeErr     error
	statusResult *PRInfo
	statusErr    error
}

func (m *mockPlatform) PlatformName() string { return m.name }

func (m *mockPlatform) Push(_ context.Context, _ PushOptions) (*CommandResult, error) {
	return m.pushResult, m.pushErr
}

func (m *mockPlatform) CreatePR(_ context.Context, _ PRCreateOptions) (*CommandResult, error) {
	return m.createResult, m.createErr
}

func (m *mockPlatform) MergePR(_ context.Context, _ PRMergeOptions) (*CommandResult, error) {
	return m.mergeResult, m.mergeErr
}

func (m *mockPlatform) PRStatus(_ context.Context, _ PRStatusOptions) (*PRInfo, error) {
	return m.statusResult, m.statusErr
}

// --- interface compliance ---

func TestAllPlatformsSatisfyInterface(t *testing.T) {
	var _ Platform = &GitHubPlatform{}
	var _ Platform = &GitLabPlatform{}
	var _ Platform = &AzureDevOpsPlatform{}
	var _ Platform = &mockPlatform{}
}

// --- branch protection ---

func TestIsProtectedBranch(t *testing.T) {
	cases := []struct {
		branch   string
		expected bool
	}{
		{"main", true},
		{"master", true},
		{"feat/new-feature", false},
		{"fix/bug-123", false},
		{"develop", false},
		{"release/1.0", false},
	}

	for _, tc := range cases {
		t.Run(tc.branch, func(t *testing.T) {
			got := isProtectedBranch(tc.branch)
			if got != tc.expected {
				t.Errorf("isProtectedBranch(%q) = %v, want %v", tc.branch, got, tc.expected)
			}
		})
	}
}

// --- utility functions ---

func TestExtractURL(t *testing.T) {
	cases := []struct {
		name     string
		input    string
		expected string
	}{
		{
			"github pr output",
			"Creating pull request...\nhttps://github.com/owner/repo/pull/42\n",
			"https://github.com/owner/repo/pull/42",
		},
		{
			"no url in output",
			"some output without urls",
			"",
		},
		{
			"multiple lines with url",
			"info: something\nhttps://gitlab.com/group/project/-/merge_requests/7\ndone",
			"https://gitlab.com/group/project/-/merge_requests/7",
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := extractURL(tc.input)
			if got != tc.expected {
				t.Errorf("extractURL() = %q, want %q", got, tc.expected)
			}
		})
	}
}

func TestBoolFlag(t *testing.T) {
	if boolFlag(true) != "true" {
		t.Error("boolFlag(true) should return \"true\"")
	}
	if boolFlag(false) != "false" {
		t.Error("boolFlag(false) should return \"false\"")
	}
}

// --- gitlab MR output parsing ---

func TestParseGitLabMROutput(t *testing.T) {
	output := `title: Fix login redirect
state: merged
url: https://gitlab.com/group/project/-/merge_requests/42
`
	info := parseGitLabMROutput(output)

	if info.Title != "Fix login redirect" {
		t.Errorf("Title = %q, want %q", info.Title, "Fix login redirect")
	}
	if info.State != "merged" {
		t.Errorf("State = %q, want %q", info.State, "merged")
	}
	if info.URL != "https://gitlab.com/group/project/-/merge_requests/42" {
		t.Errorf("URL = %q", info.URL)
	}
}

// --- tool registration ---

func TestToolDefinitions(t *testing.T) {
	tools := []struct {
		name string
		tool func() interface{ GetName() string }
	}{
		{"push", func() interface{ GetName() string } { t := pushTool(); return &t }},
		{"create_pr", func() interface{ GetName() string } { t := createPRTool(); return &t }},
		{"merge_pr", func() interface{ GetName() string } { t := mergePRTool(); return &t }},
		{"pr_status", func() interface{ GetName() string } { t := prStatusTool(); return &t }},
	}

	for _, tc := range tools {
		t.Run(tc.name, func(t *testing.T) {
			tool := tc.tool()
			if tool.GetName() != tc.name {
				t.Errorf("tool name = %q, want %q", tool.GetName(), tc.name)
			}
		})
	}
}

// --- mock-based handler tests ---

func TestHandlePushProtectedBranch(t *testing.T) {
	// handlePush reads branch from args or currentBranch()
	// We test the protection logic directly since currentBranch() depends on git
	for _, branch := range []string{"main", "master"} {
		if !isProtectedBranch(branch) {
			t.Errorf("expected %q to be protected", branch)
		}
	}
}

func TestMockPlatformPush(t *testing.T) {
	mock := &mockPlatform{
		name:       "test",
		pushResult: &CommandResult{Success: true, Output: "pushed"},
	}

	result, err := mock.Push(context.Background(), PushOptions{
		Remote: "origin",
		Branch: "feat/test",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !result.Success {
		t.Error("expected success")
	}
}

func TestMockPlatformCreatePR(t *testing.T) {
	mock := &mockPlatform{
		name:         "test",
		createResult: &CommandResult{Success: true, URL: "https://example.com/pr/1"},
	}

	result, err := mock.CreatePR(context.Background(), PRCreateOptions{
		Title: "test PR",
		Body:  "test body",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result.URL != "https://example.com/pr/1" {
		t.Errorf("URL = %q", result.URL)
	}
}

func TestMockPlatformMergePR(t *testing.T) {
	mock := &mockPlatform{
		name:        "test",
		mergeResult: &CommandResult{Success: true, Output: "merged"},
	}

	result, err := mock.MergePR(context.Background(), PRMergeOptions{
		Identifier: "42",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !result.Success {
		t.Error("expected success")
	}
}

func TestMockPlatformPRStatus(t *testing.T) {
	mock := &mockPlatform{
		name: "test",
		statusResult: &PRInfo{
			Identifier: "42",
			Title:      "test PR",
			State:      "open",
			URL:        "https://example.com/pr/42",
			Source:     "feat/test",
			Target:     "main",
		},
	}

	info, err := mock.PRStatus(context.Background(), PRStatusOptions{Identifier: "42"})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if info.Identifier != "42" {
		t.Errorf("Identifier = %q", info.Identifier)
	}
	if info.State != "open" {
		t.Errorf("State = %q", info.State)
	}
}

func TestMockPlatformFailure(t *testing.T) {
	mock := &mockPlatform{
		name:       "test",
		pushResult: &CommandResult{Success: false, Output: "rejected"},
		pushErr:    fmt.Errorf("push rejected"),
	}

	result, err := mock.Push(context.Background(), PushOptions{
		Remote: "origin",
		Branch: "feat/test",
	})
	if err == nil {
		t.Fatal("expected error")
	}
	if result.Success {
		t.Error("expected failure")
	}
}
