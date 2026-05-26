# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.9.6] - 2026-05-26

### Fixed

- Revert hooks.json event names back to Gemini CLI values (`BeforeTool`, `AfterTool`, `BeforeAgent`) — previous rename to Claude Code names broke Gemini CLI v0.43.0

## [0.9.5] - 2026-05-25

### Fixed

- Fix hooks.json: migrate deprecated event names (`BeforeTool`/`AfterTool`/`BeforeAgent`) to standard (`PreToolUse`/`PostToolUse`/`UserPromptSubmit`) — fixes Claude Code v2.1 plugin load failure
- Extend pre-tool hook scripts to handle both Gemini CLI and Claude Code tool names (`write_file`/`Write`/`create`, `replace`/`Edit`/`edit`, `run_shell_command`/`Bash`/`bash`)

### Removed

- Remove redundant `hooks/policy.json` — content merged into unified `hooks/hooks.json`

## [0.9.4](https://github.com/e-roux/agent-plugins/compare/0.9.3...0.9.4) - 2026-05-20

### Added

- **mcp/release**: add `release_status` tool — read-only report of clean tree, latest tag, changelog validity, inferred next version, and CI detection
- **mcp/release**: add `create_release` tool — creates a platform release for an already-pushed tag (GitHub: `gh release create`, GitLab: `glab release create`, Azure DevOps: unsupported with guidance)
- **skills/git**: add `git-release.md` skill resource — standardized two-phase release workflow (release PR → tag → publish) with changelog format rules, version inference, capability-based enhancements (signed tags, SBOM, attestations), and platform-specific guidance for BoschDevCloud personal repos (no runners)
- **hooks/pre-tool**: add `changelog-guard` — blocks `git tag vX.Y.Z` when the version heading is absent from `CHANGELOG.md`; first-time tagger guided to run the release PR workflow
- **hooks/post-tool**: add release reminder — injects `additionalContext` after a successful `git tag` command with next-step instructions (push tag, build artifacts, create platform release)
- **makefile**: add `changelog` target — validates CHANGELOG.md has `[Unreleased]` section and only allowed subsection headers (`Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`); wired into `make check` (dev plugin) and `make lint` (root)

### Changed

- **skills/git**: extend tool routing table with `release_status` and `create_release` MCP tools; add `git-release.md` to mandatory resource list
- **hooks/post-tool**: refactor secret-redaction output path to support simultaneous `modifiedResult` + `additionalContext` in a single JSON response

## [0.9.3](https://github.com/e-roux/agent-plugins/compare/0.9.2...0.9.3) - 2026-05-18

### Fixed

- **hooks/post-tool**: move MCP git-ops circuit breaker before bash-only guard — it was dead code, never reachable
- **hooks/pipeline-chainguard**: handle `mcp__git-ops__push` postToolUse events; CI monitoring now fires for MCP-based pushes, not only bash `git push`
- **hooks/pipeline-chainguard**: extract `_ci_context` helper to eliminate duplicated CI instruction blocks

## [0.9.2](https://github.com/e-roux/agent-plugins/compare/0.9.1...0.9.2) - 2026-05-18

### Changed

- **meta**: verified against copilot-cli v1.0.48 / sdk v0.2.2
- **meta**: `userPromptSubmitted` hooks can now handle requests directly, bypassing the LLM (v1.0.44)
- **meta**: HTTP hook type supported — hooks can POST JSON payloads to a URL instead of running a local command (v1.0.41)
- **meta**: `preToolUse.matcher` regex now works correctly — hooks with matcher run only for matching tool names (v1.0.36 fix)

## [0.9.1](https://github.com/e-roux/agent-plugins/compare/0.9.0...0.9.1) - 2026-04-24

### Fixed

- **hooks/pre-tool**: qa-gate-guard now surfaces full `make qa` output in denial message for immediate visibility
- **mcp/platform**: improve platform probe fallback when remote URL is inconclusive

## [0.9.0](https://github.com/e-roux/agent-plugins/compare/0.8.0...0.9.0) - 2026-04-24

### Added

- **hooks/pre-tool**: add blocking `qa-gate-guard` — `git commit` is denied unless `make qa` passes with zero errors when a `Makefile` exists

### Changed

- **hooks/pre-tool**: enforce warnings policy in qa-gate-guard; warnings must be fixed when feasible, not silently ignored
- **hooks/pre-tool**: allow PEP 723 script blocks (`# ///`) and `# noqa` annotations in no-comments guard

## [0.8.0](https://github.com/e-roux/agent-plugins/compare/0.7.1...0.8.0) - 2026-04-24

### Added

- **mcp**: integrate `mcp-git-ops` server for platform-agnostic push, create_pr, merge_pr, pr_status
- **hooks/pre-tool**: circuit breaker redirects bash git-push/pr-create/pr-merge to MCP tools when available
- **hooks/post-tool**: trip circuit breaker on MCP tool failures to prevent deadlock
- **skills/git**: tool routing table — MCP preferred, bash fallback
- **skills/git**: git-pull-request resource updated with MCP-first workflow + Azure DevOps

## [0.7.1](https://github.com/e-roux/agent-plugins/compare/0.7.0...0.7.1) - 2026-04-23

### Fixed

- **hooks/pre-tool**: branch-first guard now falls back to `CWD` when `FILE_DIR` doesn't exist — previously, creating a file in a new subdirectory bypassed the guard entirely

## [0.7.0](https://github.com/e-roux/agent-plugins/compare/0.6.0...0.7.0) - 2026-04-23

### Added

- **hooks/pre-tool**: add `branch-first-guard` — blocks `edit`/`create` when current branch is `main`/`master`
- **hooks/pre-tool**: extend `branch-first-guard` to `bash` tool — also blocks shell-level file writes on `main`/`master`
- **hooks/scripts**: add `branch-check-turn.sh` — Claude Code `UserPromptSubmit` hook injects branch status before every turn
- **skills/git**: add branch-first workflow as first core principle with naming convention

### Fixed

- **hooks/pre-tool**: read `toolCalls` array from `preToolUse` input (was incorrectly reading `.toolName`/`.toolArgs` — all guards were silently bypassed)
- **hooks/pre-tool**: handle unborn branches via `symbolic-ref` fallback in `_current_branch_for_path`

## [0.6.0](https://github.com/e-roux/agent-plugins/compare/0.5.0...0.6.0) - 2026-04-23

### Added

- **hooks/pre-tool**: add `branch-first-guard` to `bash` tool — blocks shell-level file writes (`echo >`, `tee`, `sed -i`) on `main`/`master`

## [0.5.0](https://github.com/e-roux/agent-plugins/compare/0.4.5...0.5.0) - 2026-04-22

### Added

- **skills/git**: add `git` skill — opinionated commit/PR workflow with `make qa` quality gate, scoped conventional commits, and branch safety rules

## [0.4.5](https://github.com/e-roux/agent-plugins/compare/0.4.4...0.4.5) - 2026-04-16

### Changed

- **config**: split dual manifests — `plugin.json` (root, full Copilot CLI format) and `.claude-plugin/plugin.json` (minimal, Claude Code compatible)
- **hooks**: split hook policies — `hooks/policy.copilot.json` (camelCase) and `hooks/policy.json` (PascalCase, Claude Code auto-discover)

## [0.2.0](https://github.com/e-roux/agent-plugins/compare/0.1.0...0.2.0) - 2026-04-02

### Added

- **hooks/pre-tool**: add `no-comments-guard` — blocks comment lines in source code files (`.go`, `.ts`, `.tsx`, `.js`, `.jsx`, `.py`, `.rs`, `.java`, `.c`, `.cpp`, `.h`, `.cs`, `.rb`, `.swift`, `.kt`); shebang lines, test files, Makefiles, and config files excluded
- **hooks/post-tool**: add `postToolUse` output redaction hook — strips GitHub PATs, AWS keys, OpenAI keys, private keys, and long hex tokens from bash output before the LLM sees them

## [0.1.0](https://github.com/e-roux/agent-plugins/releases/tag/0.1.0) - 2026-03-28

### Added

- **hooks/pre-tool**: initial `secrets-guard` — detects hardcoded credentials in `edit`/`create` tool calls
- **hooks/pre-tool**: initial `branch-guard` — blocks `git push/merge ... main` and `git commit --no-verify`
- **hooks/pre-tool**: initial `migration-guard` — blocks `DROP TABLE`, `TRUNCATE TABLE`, `DELETE FROM` in bash commands that reference migration file paths
- **hooks/scripts**: `session-start` hook — injects "Dev Guards Active" policy banner
- **skills/dev**: skill definition documenting all three guards with examples

