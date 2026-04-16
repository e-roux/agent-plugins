# Agent instructions

This repository is a monorepo providing a Makefile development plugin for AI coding agents. It enforces strict Makefile structure and the make-first workflow. Two agents are currently supported: GitHub Copilot CLI and OpenCode.

## Repository structure

```
agent-plugin-makefile/
├── hooks/           Hook scripts (session-start, pre-tool)
├── skills/          Agent skills (makefile, python, shell, testing, banner)
└── test/
    └── copilot-cli/ Tests for the Copilot CLI integration
```

## Policy enforcement

The plugin enforces two categories of rules:

### 1. Makefile structure (via `create` and `edit` tool hooks)

When the agent creates or edits a file named `Makefile`, `makefile`, or `GNUmakefile`, the hook validates:
- `.SILENT:` is present
- `.ONESHELL:` is present
- `.DEFAULT_GOAL` is declared
- No `@` prefix appears on recipe lines (tab-indented lines)
- A `qa` target is declared (in `.PHONY:` or as a recipe)

If any check fails, the tool call is **denied** with a specific error message explaining the violation.

### 2. Direct tool invocations (via `bash` tool hook)

These commands are always blocked — the agent must use `make <target>` instead:
`pytest`, `ruff format`, `ruff check`, `go test`, `go build`, `golangci-lint`, `eslint`, `jest`, `bun test`, `black`

## Version synchronisation

`opencode/package.json` is the version source of truth. `copilot-cli/plugin.json` must carry the same version. The `make version.check` target enforces this and is part of `make qa`. Never commit with mismatched versions.

## Development guidelines

- Implement tests before writing implementation code.
- Keep the Makefile well organised. Do not add targets without a clear purpose.
- Minimise third-party dependencies. Security is a primary concern.
- Run `make qa` before every commit. `make qa` runs `version.check + check + test`.

## Testing

### Copilot CLI hooks (`copilot-cli/`)

Hooks are unit-tested with bats (`test/copilot-cli/hooks.bats`) and end-to-end with a real Copilot CLI invocation (`test/copilot-cli/hooks_e2e.bats`).

E2E tests must:

- Work from a `TMPDIR` — never from the repository root.
- Copy hook scripts into the temporary directory under `.github/hooks/scripts/` and write a corresponding `policy.json` before invoking `copilot`.
- Use only model `gpt-4.1` (`--model "gpt-4.1"`). This is not negotiable.
- Pass `--disable-builtin-mcps`, `--no-ask-user`, and `--allow-all-tools` for non-interactive execution.
- Pass the prompt via `-p <PROMPT>`.
- Evaluate the outcome from audit logs (`pre-tool-denied.log`, `session-start.log`) and the CLI response.
- Use `/env` to verify loaded skills, hooks, and plugin registration during interactive debugging.

### OpenCode plugin (`opencode/`)

The rule engine is unit-tested with `bun test` (`test/opencode/core.test.ts`) and end-to-end with a real OpenCode invocation (`test/opencode/e2e.bats`).

E2E tests must:

- Work from a `TMPDIR`.
- Copy `core.ts` and `index.ts` into `.opencode/plugins/` in the temporary directory.
- Evaluate denied commands from `.opencode/logs/pre-tool-denied.log`.

## References

### GitHub Copilot CLI

- Plugin reference: https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference
- Hooks configuration: https://docs.github.com/en/copilot/reference/hooks-configuration

### OpenCode

- Plugin documentation: https://opencode.ai/docs/plugins
