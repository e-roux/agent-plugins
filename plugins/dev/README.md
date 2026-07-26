# agent-plugin-dev

General-purpose development guards for any repository.
Works with **Copilot CLI**, **Claude Code**, **Gemini CLI**, **pi**, and **opencode**.

## Guards

| Guard | Hook phase | What it does |
|-------|-----------|-------------|
| `secrets-guard` | preTool + postTool | Blocks hardcoded credentials in source files; redacts leaked tokens from tool output |
| `no-comments-guard` | preTool | Blocks `//`, `/* */`, `#` comment lines in code files (exempts shebang, `# noqa`, PEP 723) |
| `branch-first-guard` | preTool + userPromptSubmit | Blocks file edits and output redirection on `main`/`master` |
| `branch-guard` | preTool | Blocks `git push`/`git merge` directly to `main`/`master` |
| `no-verify-guard` | preTool | Blocks `git commit --no-verify` |
| `migration-guard` | preTool | Blocks `DROP`/`TRUNCATE`/`DELETE` in SQL migration contexts |
| `qa-gate-guard` | preTool | Blocks `git commit` unless `make qa` passes (zero failures) |
| `makefile-guard` | preTool | Validates Makefile directives on create/edit (`.SILENT:`, `.ONESHELL:`, `qa` target) |
| `tool-redirect` | preTool | Auto-redirects direct tool invocations (`pytest`, `ruff`, `go test`, etc.) to `make` targets |
| `mcp-redirect` | preTool | Denies bash `git push`/`gh pr` commands when `mcp-git-ops` is available |
| `changelog-guard` | preTool | Validates `git tag` commands reference a version heading in `CHANGELOG.md` |
| `pipeline-chainguard` | postTool | After push, injects CI monitoring instructions (`gh run list`, `glab ci status`) |

## Install

### Copilot CLI / Claude Code

```bash
copilot plugin marketplace add e-roux/agent-plugins
```

### Gemini CLI

```bash
gemini extensions install https://github.com/e-roux/agent-plugins/plugins/dev
```

### Pi

```bash
pi install git:github.com/e-roux/agent-plugins
```

### opencode

Configured automatically via the repository root `opencode.json`.

## Skills

Bundled in `skills/`:

| Skill | Purpose |
|-------|---------|
| `git` | Branch-first workflow, QA gating, commit message conventions, MCP tool routing |
| `makefile` | Enforces `.SILENT:`, `.ONESHELL:`, mandatory `qa` target, box-drawing help banners |
| `python` | uv-only execution, ruff + mypy toolchain, TDD-first, type annotations required |
| `shell` | Defensive scripting (`set -euo pipefail`), Make-centric workflow |
| `testing` | TDD workflow, unit/integration/e2e categorization, Make-based execution |

## MCP Server

Exposes the `git-ops` MCP server for platform-agnostic git operations.
Requires the binary in `$PATH`:

```bash
GOBIN=${XDG_BIN_HOME:-$HOME/.local/bin} go install github.com/e-roux/mcp-git-ops@latest
```
