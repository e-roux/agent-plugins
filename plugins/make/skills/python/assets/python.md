# Python Makefile Implementation
## Tools

- **Package manager**: `uv` - `uv sync --all-groups --all-extras`
- **Formatter**: `ruff` - `uv run ruff format`
- **Linter**: `ruff` - `uv run ruff check --fix`
- **Type checker**: `zuban` - `uv run zmypy`
- **Test runner**: `pytest` - `uv run pytest`

## Configuration

```makefile
UV := uv
PYTHON := $(UV) run python
PYTEST := $(UV) run pytest
RUFF := $(UV) run ruff
ZUBAN := $(UV) run zmypy
```

## Test Markers

Use pytest markers for test categorization:

- `pytest` - runs unit tests (default)
- `pytest -m integration` - integration tests
- `pytest -m e2e` - end-to-end tests
- `pytest -m benchmark -n0` - benchmark tests

## Cleanup

Python-specific artifacts:
```bash
rm -rf .pytest_cache .ruff_cache .mypy_cache .coverage htmlcov
find . -type d -name "__pycache__" -exec rm -rf {} +
find . -type d -name "*.egg-info" -exec rm -rf {} +
find . -type f -name "*.pyc" -delete
```

Deep clean removes `.venv/` via `distclean`.
