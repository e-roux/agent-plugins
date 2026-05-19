---
name: make-first
description: "Make-centric development workflow. Always use make targets instead of running tools directly. Enforces Makefile structure: .SILENT:, .ONESHELL:, .DEFAULT_GOAL := help, no @ prefix, mandatory qa target."
---

# Make-First Workflow — Active

## Core Rule

Always use `make <target>` instead of running tools directly. The `BeforeTool` hook blocks direct invocations and redirects to the appropriate make target.

| Direct invocation (blocked) | Use instead |
|-----------------------------|-------------|
| `pytest` | `make test` |
| `ruff format` / `ruff check` | `make fmt` / `make lint` |
| `go test ./...` | `make test` |
| `go build ./...` | `make build` |
| `golangci-lint run` | `make lint` |
| `eslint` / `jest` / `bun test` | `make lint` / `make test` |
| `black` / `mypy` | `make fmt` / `make typecheck` |

## Required Makefile Structure

Every `Makefile` must have:

```makefile
.SILENT:
.ONESHELL:
.DEFAULT_GOAL := help
```

- **`.SILENT:`** — suppress recipe echoing (no `@` prefix needed or allowed)
- **`.ONESHELL:`** — run each recipe in a single shell instance
- **`.DEFAULT_GOAL := help`** — default target must be `help`
- **No `@` prefix** on recipe lines (redundant with `.SILENT:` and forbidden)
- **`qa` target** — mandatory; runs `fmt + lint + typecheck + test`

## Mandatory Targets

| Target | Purpose |
|--------|---------|
| `make qa` | Full quality gate (fmt + lint + typecheck + test) |
| `make fmt` | Format source files |
| `make lint` | Run linters |
| `make test` | Run tests |
| `make help` | Show available targets (default) |

## Python Toolchain

Use `uv` — never `pip`, `python`, or `virtualenv` directly:

```bash
# ✗ Forbidden
pip install requests
python script.py

# ✓ Correct
uv add requests
uv run script.py
```

## Shell Scripts

- Use `#!/usr/bin/env bash` shebang
- Set `set -euo pipefail` at the top
- Use `local` for function variables
- Quote all variable expansions: `"$var"` not `$var`
