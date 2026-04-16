# Changelog

## [0.4.5]

- Split dual manifests: `plugin.json` (root, full Copilot CLI format) and `.claude-plugin/plugin.json` (minimal, Claude Code compatible — name/description/version/author/license/keywords only)
- Split hooks: `hooks/policy.copilot.json` (camelCase, Copilot CLI) and `hooks/policy.json` (PascalCase, Claude Code auto-discover format using `${CLAUDE_PLUGIN_ROOT}`)

## [0.4.4]

- Move plugin manifest to `.claude-plugin/plugin.json` — DRY path for both Copilot CLI and Claude Code

## [0.4.3]

- Align with Vulcan v0.18.0 dual-tool DRY guidance (no changes needed — plugin has no `.agents/skills/` references)
- Bump patch version for metadata alignment

## [0.4.2]

- Bump Copilot CLI version to 1.0.27 (SDK unchanged at 0.2.2)
- Hook scripts use `COPILOT_PLUGIN_ROOT` env var (CLI 1.0.26) for log paths with fallback to dirname-based resolution
- Document `COPILOT_PLUGIN_ROOT` availability in skill description

## [0.4.1]

- Bump Copilot CLI version to 1.0.25, add SDK version 0.2.2 to metadata
- Document `/env` command in skill for verifying guards are loaded (CLI 1.0.25)
- Note remote session (`--remote`/`/remote`) compatibility in skill and extension docs
- Skill instructions now persist correctly across conversation turns (CLI 1.0.25 fix)

## [0.4.0]

### Added

- **pipeline-chainguard** (Layer 1): `postToolUse` shell hook that detects
  `git push` and injects `additionalContext` instructing the agent to check CI
  status via `gh run list` (GitHub) or `glab ci status` (GitLab). Handles
  failed pushes, bare pushes, and explicit remote/branch arguments.
- **pipeline-chainguard** (Layer 2): opt-in CLI extension
  (`extensions/pipeline-chainguard/extension.mjs`) that autonomously monitors
  CI after push — waits for pipeline registration, polls status, and sends
  failure logs back to the agent via `session.send()`. Registers a
  `check_ci_pipeline` custom tool for manual checks with optional wait mode.
- 6 bats tests covering chainguard detection, failed push handling, bare push
  fallback, and provider-specific output.
- Session-start banner now mentions pipeline-chainguard guard.

## [0.3.2]

- Add `postToolUse` output redaction hook: detects and strips GitHub PATs, AWS keys, OpenAI keys, private keys, and long hex tokens from bash output before the LLM sees them via `modifiedResult` (CLI v1.0.24)

## [0.3.1]

- Bump Copilot CLI version to 1.0.24; no content changes

## [0.2.1]

- Bump Copilot CLI version to 1.0.22; no content changes

## [0.2.0] - 2026-04-02

### Added

- **no-comments-guard**: new `preToolUse` guard that blocks comment lines (`//`, `/*`, `*/`, `#`) in
  source code files (`.go`, `.ts`, `.tsx`, `.js`, `.jsx`, `.py`, `.rs`, `.java`, `.c`, `.cpp`, `.h`,
  `.cs`, `.rb`, `.swift`, `.kt`). Shebang lines (`#!/`), test files, Makefiles, shell scripts, and
  config files are excluded. Rationale: comments can conflict with code, confusing the LLM about
  which to follow ([AMPECO Infinite Engineer](https://p.ampeco.com/infinite-engineer/infinite-engineer)).
- **skills directory restructured**: `copilot-cli/skill/SKILL.md` → `copilot-cli/skills/dev/SKILL.md`
  per the latest copilot-cli plugin spec (skills must live in named subdirectories).
- **plugin.json**: `"skills"` path updated to `"skills/"`, version bumped to `0.2.0`, added
  `"self-documenting"` keyword.
- **session-start.sh**: banner updated to list `no-comments-guard`.
- **hooks.bats**: 7 new tests for `no-comments-guard` (27 tests total, 0 failures).

### Changed

- **pre-tool.sh**: refactored to extract `CONTENT` once at the top (shared between `secrets-guard`
  and `no-comments-guard`), eliminating duplicate `jq` calls. Added `_is_test_or_config()` helper
  to deduplicate the file-exclusion check.

## [0.1.0] - 2026-03-28

### Added

- Initial release of `agent-plugin-dev`.
- **copilot-cli plugin**
  - `session-start` hook: injects "Dev Guards Active" policy banner with all three guard names.
  - `preToolUse` hook (`pre-tool.sh`):
    - **secrets-guard**: detects hardcoded credentials (`JWT_SECRET`, `API_KEY`, `CLIENT_SECRET`, `DB_PASSWORD`, etc.) in `edit`/`create` tool calls on code files. Skips test files, templates, and markdown.
    - **branch-guard**: blocks `git push/merge ... main` (with boundary-aware `[^&|;]*\bmain\b` regex to avoid false positives across `&&` chains), and `git commit --no-verify`.
    - **migration-guard**: blocks `DROP TABLE`, `TRUNCATE TABLE`, `DELETE FROM` in bash commands that reference migration file paths.
  - Skill definition (`SKILL.md`) documenting all three guards with examples.
- **Test suite**: 19 bats unit tests (19/19 passing).
