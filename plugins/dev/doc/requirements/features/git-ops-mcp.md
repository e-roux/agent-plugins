# Feature: Git Operations MCP Server

## Context

Agents currently use raw bash commands (`git push`, `gh pr create`, `glab mr create`)
for git operations. This has several problems:

- Platform-specific bash templates bloat skill context
- Guards must parse bash command strings to enforce policy (fragile regex matching)
- No unified interface — the agent must know which CLI to call per platform
- Azure DevOps is unsupported in the current skill resources

## Solution

A lightweight MCP server (`mcp-git-ops`, written in Go) that exposes
platform-agnostic git operation tools. The server auto-detects the hosting
platform from the git remote URL and delegates to `gh`, `glab`, or `az repos`.

Branch protection is enforced inside the tool — push and create_pr refuse to
operate on protected branches regardless of how the tool is invoked.

## Architecture

```
mcp-git-ops (Go binary, stdio MCP server)
├── Platform interface (compile-time parity guarantee)
├── GitHub adapter   (gh CLI)
├── GitLab adapter   (glab CLI)
└── Azure DevOps adapter (az repos CLI)

.mcp.json (shared by Copilot CLI + Claude Code)

pre-tool.sh
├── MCP available → deny bash git-push, redirect to MCP tool
└── MCP unavailable (circuit breaker) → allow bash, branch-guard still active
```

## Acceptance Criteria

### MCP Server (separate repo: e-roux/mcp-git-ops)

- AC-001: Go binary, single process, stdio MCP transport
- AC-002: Tools: `push`, `create_pr`, `merge_pr`, `pr_status`
- AC-003: All four tools implemented identically for GitHub, GitLab, Azure DevOps
- AC-004: Platform auto-detected from `git remote get-url origin`; overridable via `GIT_OPS_PLATFORM` env var
- AC-005: `push` and `create_pr` refuse operations on protected branches (configurable via `PROTECTED_BRANCHES` env var, default: `main,master`)
- AC-006: `Platform` Go interface enforces operation parity at compile time
- AC-007: Unit tests verify branch protection, URL extraction, interface compliance

### Plugin Integration (this repo: agent-plugin-dev)

- AC-008: `.mcp.json` at project root references `mcp-git-ops` binary
- AC-009: `plugin.json` and `.claude-plugin/plugin.json` declare `mcpServers` for plugin distribution
- AC-010: `pre-tool.sh` denies `bash git push` / `gh pr create` / `glab mr create` / `az repos pr create` when MCP server is available, redirecting to MCP tools
- AC-011: Circuit breaker: if `mcp-git-ops` binary is not on PATH or circuit is tripped (recent MCP failure), pre-tool.sh allows bash through — no deadlock
- AC-012: `post-tool.sh` trips the circuit breaker (writes timestamp to `/tmp/.mcp-git-ops-cb`) when any `mcp__git-ops__*` tool returns an error
- AC-013: Circuit breaker auto-resets after 300 seconds
- AC-014: Branch-guard (no push to main) remains active as a fallback regardless of MCP availability

### Skill Adaptation

- AC-015: `skills/git/SKILL.md` includes tool routing table: MCP tool → bash fallback
- AC-016: `skills/git/resources/git-pull-request.md` simplified — platform-branching bash block replaced with MCP tool reference + fallback note
- AC-017: Tool descriptions are minimal (one sentence each) to conserve agent context budget

## Fallback Strategy

```
Agent wants to push
  │
  ├─→ Skill says "use mcp__git-ops__push"
  │     ├─→ MCP tool succeeds → done
  │     └─→ MCP tool fails → error includes fallback hint
  │           └─→ Agent retries with bash
  │                 └─→ pre-tool.sh: circuit breaker OPEN → allow bash
  │                       (branch-guard still blocks push to main)
  │
  └─→ MCP not installed
        └─→ pre-tool.sh: binary not on PATH → allow bash
              (branch-guard still blocks push to main)
```

Three safety layers always active regardless of MCP:
1. Branch-guard: no push to main (existing)
2. No `--no-verify` (existing)
3. Pipeline-chainguard fires on bash git-push (existing)

## Constraints

- MCP server must have minimal memory and CPU footprint (Go binary, ~5-8 MB RSS)
- MCP server lives in a separate repository (e-roux/mcp-git-ops)
- Tools must never deadlock the agent — circuit breaker ensures fallback
- No new dependencies in the plugin repo — only references the Go binary

## Non-Goals

- Replacing `git commit` (stays as bash — commit message formatting is skill-level guidance)
- CI pipeline monitoring (stays in pipeline-chainguard extension/hook)
- Enforcing branch naming conventions (discipline, not a tool concern)
