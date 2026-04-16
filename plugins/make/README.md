# agent-plugin-makefile

An opinionated Makefile development plugin for AI coding agents. It enforces strict Makefile structure (`.SILENT:`, `.ONESHELL:`, no `@` prefix in recipes, mandatory `qa` target) and blocks direct tool invocations that bypass Make targets.

Two agents are currently supported:

- [GitHub Copilot CLI](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference) — installed via GitHub subdir
- [OpenCode](https://opencode.ai/docs/plugins) — published as an npm package

---

## Repository layout

```
agent-plugin-makefile/
├── copilot-cli/          GitHub Copilot CLI plugin (name: make-first)
│   ├── plugin.json       Plugin manifest
│   ├── .mcp.json         MCP server configuration
│   ├── bin/              mcp-banner.sh wrapper (builds binary on first run)
│   ├── hooks/            Hook configuration and shell scripts
│   ├── skills/           Skill definitions (makefile, python)
│   └── src/              mcp-banner Go source (ships with plugin install)
├── opencode/             OpenCode npm package
│   ├── package.json      npm manifest (version source of truth)
│   ├── tsconfig.json     TypeScript configuration
│   ├── core.ts           Rule engine + Makefile validator (pure, testable)
│   ├── index.ts          Plugin entry point
│   └── command/          Command documentation
└── test/
    ├── copilot-cli/      Copilot CLI hook tests
    └── opencode/         OpenCode plugin tests
```

---

## Policy

### Makefile structure (enforced on `create` / `edit` tool calls)

Every Makefile MUST include these directives and targets:

| Requirement | Rule |
|-------------|------|
| `.SILENT:` | Suppresses recipe echoing — **no `@` prefix needed** |
| `.ONESHELL:` | Runs each recipe in a single shell instance |
| `.DEFAULT_GOAL := help` | Default target is `help` |
| No `@` in recipes | Redundant with `.SILENT:` and **forbidden** |
| `qa:` target | Mandatory quality gate (`check + test`) |

### Direct tool invocations (enforced on `bash` tool calls)

These commands are blocked — use `make <target>` instead:

| Forbidden | Replacement |
|-----------|-------------|
| `pytest tests/` | `make test` |
| `ruff format src/` | `make fmt` |
| `ruff check src/` | `make lint` |
| `go test ./...` | `make test` |
| `go build ./...` | `make build` |
| `golangci-lint run` | `make lint` |
| `eslint --fix .` | `make lint` |
| `jest --coverage` | `make test` |
| `bun test` | `make test` |
| `black .` | `make fmt` |

---

## Installation

### GitHub Copilot CLI

```bash
copilot plugin install e-roux/agent-plugin-makefile:copilot-cli
```

The `mcp-banner` MCP server is compiled from source on first use. It requires `go` to be installed (`brew install go`). Run `make mcp.build` to pre-compile it manually.

### OpenCode

Add the package to your `opencode.json` configuration:

```json
{
  "plugin": ["opencode-makefile-enforcer"]
}
```

---

## Resources by agent

### GitHub Copilot CLI (`copilot-cli/`)

| Resource | Path | Role |
|----------|------|------|
| Plugin manifest | `copilot-cli/plugin.json` | Declares skills, hooks, and MCP server paths |
| Hook configuration | `copilot-cli/hooks/policy.json` | Registers `sessionStart` and `preToolUse` hooks |
| Pre-tool hook | `copilot-cli/hooks/scripts/pre-tool.sh` | Blocks forbidden bash commands; validates Makefile on create/edit |
| Session-start hook | `copilot-cli/hooks/scripts/session-start.sh` | Displays policy banner; writes audit log |
| Skill definitions | `copilot-cli/skills/` | `makefile` and `python` skill contexts |
| MCP server wrapper | `copilot-cli/bin/mcp-banner.sh` | Builds `mcp-banner` from source on first run, then execs it |
| MCP server source | `copilot-cli/src/` | Go source for `mcp-banner` — ships with the plugin; requires `go` to compile |

### OpenCode (`opencode/`)

| Resource | Path | Role |
|----------|------|------|
| npm manifest | `opencode/package.json` | Package definition; version source of truth |
| TypeScript config | `opencode/tsconfig.json` | Compiler options for Bun/ESNext |
| Rule engine | `opencode/core.ts` | Pure TypeScript: `CommandRule`, `MakefileCheck`, `intercept()`, `validateMakefile()` |
| Plugin entry point | `opencode/index.ts` | Subscribes to `tool.execute.before`; handles bash, create, and edit tools |
| Command documentation | `opencode/command/makefile.md` | Rendered when the user invokes the `/makefile` command |

---

## Version synchronisation

The version in `opencode/package.json` is the single source of truth. The version in `copilot-cli/plugin.json` must match it at all times.

```bash
make version.check   # verifies both files have the same version
make qa              # runs version.check as part of the quality gate
```

---

## Tests

| Test file | Runner | Scope | Agent |
|-----------|--------|-------|-------|
| `test/copilot-cli/hooks.bats` | bats | Unit — hook script logic (session-start, bash, create, edit) | Copilot CLI |
| `test/copilot-cli/hooks_e2e.bats` | bats + copilot | E2E — real CLI invocation | Copilot CLI |
| `test/opencode/core.test.ts` | bun test | Unit — command rules + Makefile checks | OpenCode |
| `test/opencode/e2e.bats` | bats + opencode | E2E — real CLI invocation | OpenCode |

---

## Development

```bash
make sync              # install dependencies (bats, shellcheck, jq, bun)
make qa                # full quality gate: version.check + fmt + lint + typecheck + test
make copilot-cli.test  # hook unit and e2e tests only
make opencode.test     # TypeScript unit and e2e tests only
make publish           # create GitHub Release for current version
```
