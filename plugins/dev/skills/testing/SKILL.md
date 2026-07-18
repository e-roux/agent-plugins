---
name: testing
description: "Test organization and TDD practices across Python, Go, and TypeScript. Use when writing tests, organizing test directories, setting up test infrastructure, or applying TDD. Covers unit/integration/e2e categorization, test file mirroring, and Make-based execution."
license: MIT
---

# Testing Skill

Test organization conventions and TDD workflow. All test execution goes through Make (see **makefile** skill).

## TDD Cycle

Tests define expected behavior BEFORE implementation — non-negotiable.

1. Write a failing test that defines expected behavior
2. Verify it fails: `make test`
3. Implement the minimum code to pass
4. Verify it passes: `make test`
5. Refactor if needed; re-run `make test` after each change

Cover: happy path, edge cases (nil/empty/invalid), boundaries, and error conditions.

## Directory Layout

```
project/
├── src/ (or internal/ or cmd/)
└── test/                        # singular, not tests/
    ├── conftest.py              # Python: shared fixtures, auto-markers
    ├── <mirrors src structure>  # unit tests mirror source tree
    ├── integration/
    ├── e2e/
    ├── benchmark/
    └── resources/               # shared fixtures
```

**Key rule**: `test/` (singular). Unit test files mirror the source tree path.

## Test Categorization

| Category    | Location                        | Scope                                          |
|:------------|:--------------------------------|:-----------------------------------------------|
| Unit        | `test/` root (colocated in Go)  | Single function/module, no external deps        |
| Integration | `test/integration/`             | Multiple components, may need running services |
| E2E         | `test/e2e/`                     | Full system, requires deployed stack           |
| Benchmark   | `test/benchmark/`               | Performance measurement                        |

Categorized by **directory placement**, not annotations.

## Make Targets

```bash
make test              # alias for test.unit
make test.unit
make test.integration
make test.e2e
make test.benchmark
make test.all
make qa                # check + test.all — REQUIRED before completion
```

## File Naming

| Language   | Unit test file          | Test function                           |
|:-----------|:------------------------|:----------------------------------------|
| Python     | `test_<module>.py`      | `def test_<behavior>():`                |
| Go         | `<file>_test.go`        | `func Test<Behavior>(t *testing.T)`     |
| TypeScript | `<module>.test.ts`      | `it("should <behavior>", ...)`          |

## Development Workflow

1. Identify the behavior to implement or fix
2. Write failing test in the correct location
3. `make test` — confirm it fails
4. Implement the minimum code
5. `make test` — confirm it passes
6. `make qa` — mandatory before completion

See `references/lang-specifics.md` for language-specific mirroring examples, Python auto-markers, Go build tag conventions, and Make target command mappings.

