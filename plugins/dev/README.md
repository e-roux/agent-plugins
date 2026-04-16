# agent-plugin-dev

General-purpose development guards for [GitHub Copilot CLI](https://github.com/github/copilot-cli).

Provides three project-agnostic hooks that work across **any repository**:

| Guard | What it blocks |
|-------|---------------|
| `secrets-guard` | Hardcoded credentials (`JWT_SECRET`, `API_KEY`, `DB_PASSWORD`, etc.) in source files |
| `branch-guard` | Direct `git push/merge` to `main` and `git commit --no-verify` |
| `migration-guard` | Destructive SQL (`DROP TABLE`, `TRUNCATE`, `DELETE FROM`) in migration files |

## Install

```bash
copilot plugin install e-roux/agent-plugin-dev
```

## Complements

This plugin is designed to work alongside:

- [`agent-plugin-makefile`](https://github.com/e-roux/agent-plugin-makefile) — Makefile enforcement
- [`agent-plugin-python`](https://github.com/e-roux/agent-plugin-python) — uv/Python toolchain enforcement

Project-specific guards (qa-gate, scope-guard, version-guard, issue-closure) should live in the project's own `.github/hooks/`.

## Development

```bash
make test   # 19 bats tests
make qa     # check + test
```
