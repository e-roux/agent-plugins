---
name: python
description: "Python and uv development: uv run for scripts, Make-centric project workflow, TDD-first, type annotations required."
---

# Python Skill

This skill defines the mandatory workflow for both standalone Python scripts and complete Python projects, using **uv** as the universal package manager.

## MANDATORY: NO DIRECT EXECUTION

Never run `python`, `pip`, or any tool (e.g., `pytest`, `ruff format`) directly. Always use `uv run --script` (scripts) or `make` targets (projects). No exceptions.

---

## Single Scripts

For standalone files or one-off operations, you must run tools and scripts via `uv run --script`.
Running scripts with ad-hoc ad-hoc dependencies (e.g. `--with`) is not allowed. You must use PEP 723 inline script metadata.

### Common Commands
```bash
uv run script.py                   # Run a script with its embedded dependencies
uv init --script example.py        # Create script with inline metadata
uv add --script example.py requests # Add dependency to script metadata
```

See [resources/scripts.md](resources/scripts.md) for full details on script execution, stdin pipes, reproducibility, and shebangs.

---

## Projects

Python packages and applications use **GNU Make** as the standard interface for development tasks. Please load the **using-makefile** skill and adhere strictly to its requirements.

### MAKE-CENTRIC WORKFLOW
- Every development task (code formatting, linting, type checking, testing) MUST be performed via Make targets (e.g., `make test`, `make check`, `make qa`).
- The `Makefile` is your PRIMARY and ONLY allowed interface for execution in a project.
- Your work is ONLY complete when `make qa` passes. Do not stop until all checks pass. Code that hasn't passed `make qa` is considered incomplete.

### Dependency Management
- Always use `uv sync`, `uv add`, `uv remove` to manage dependencies. NEVER use `pip`.

### Python & Type Annotations
- Always require Python ≥3.12
- NEVER write a Python file without type annotations. All functions MUST have type hints for parameters and return values.

### Testing & Quality Validation
Tests are THE BASIS FOR IMPLEMENTATION. Write tests FIRST, verify they fail, then implement. Please load the `testing` skill for the full TDD workflow.
- Auto-markers via `conftest.py` (see `assets/conftest.py`) -- no manual `@pytest.mark` needed
- Marker configuration in `pyproject.toml` (see `assets/pyproject.toml.template`)

### Toolchain (enforced by plugin hooks)

| Tool | Command | Purpose |
|------|---------|---------|
| `uv` | `uv run <script>` / `uv add <pkg>` | Package manager — **no pip/python directly** |
| `ruff` | `uv run ruff format src/` | Formatting (replaces black) |
| `ruff` | `uv run ruff check --fix src/` | Linting + type-annotation rules (`ANN`, `TC`) |
| `zmypy` | `uv run zmypy src/` | Type checking via **zuban** (mypy-compatible, 20-200× faster, Rust) |
| `pytest` | `uv run pytest` | Testing |

> **Hook enforcement**: Direct `python`, `pip`, `virtualenv` calls are **denied** by the plugin's `preToolUse` hook. Direct `mypy` calls are **auto-redirected** to `make typecheck`. Always use `uv run zmypy` for type checking, never bare `mypy`.

### Configuration

- **ruff**: `ruff.toml` or `[tool.ruff]` in `pyproject.toml`. Includes `ANN` (annotations) and `TC` (type-checking imports) rule sets.
- **zmypy/zuban**: uses `[tool.mypy]` table in `pyproject.toml` (drop-in mypy config compatibility).

```toml
[tool.mypy]
strict = true
ignore_missing_imports = true
check_untyped_defs = true
warn_redundant_casts = true
warn_unused_ignores = true
show_error_codes = true
```

### Development Sequence
1. **Write Tests First**: Create failing tests in `/test` directory that define expected behavior.
2. **Implement**: Write code to satisfy tests, always with type annotations.
3. **Validate**: Run `make test` to verify tests pass.
4. **Format & Lint**: Run `make check` (ruff format + ruff check --fix + zmypy typecheck).
5. **Complete**: Run `make qa` - MANDATORY before considering work done.

### Additional Project Resources
For build backend and pure package configuration (using `uv_build`), see [resources/build.md](resources/build.md).
