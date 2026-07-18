# Language-Specific Test Conventions

## Unit Test Mirroring

### Python (`test/` mirrors `src/`)

```
src/auth/middleware.py  →  test/auth/test_middleware.py
src/auth/token.py       →  test/auth/test_token.py
src/service/xml.py      →  test/service/test_xml.py
```

### Go (colocated `_test.go` for unit tests)

```
internal/auth/middleware.go      →  internal/auth/middleware_test.go  (same pkg)
internal/auth/token.go           →  internal/auth/token_test.go
test/integration/api_test.go     # separate directory for integration/e2e
test/resources/xml/sample.xml    # shared fixtures
```

Run units: `go test -short ./internal/... ./cmd/...`  
Integration guarded by env: `INTEGRATION_TEST=true`  
E2E guarded by env: `E2E_TEST=true`

### TypeScript (`test/` mirrors `src/`)

```
src/auth/middleware.ts   →  test/auth/middleware.test.ts
src/service/parser.ts    →  test/service/parser.test.ts
```

Use `.test.ts` suffix (not `.spec.ts`).

## Python: Automatic Markers

Place in `test/conftest.py` — auto-assigns markers by directory path, no manual `@pytest.mark.xxx` needed:

```python
import pytest
from pathlib import Path

def pytest_collection_modifyitems(items):
    for item in items:
        path = Path(item.fspath)
        if "test/e2e" in str(path):
            item.add_marker(pytest.mark.e2e)
        elif "test/benchmark" in str(path):
            item.add_marker(pytest.mark.benchmark)
        elif "test/integration" in str(path):
            item.add_marker(pytest.mark.integration)
```

Register markers in `pyproject.toml`:

```toml
[tool.pytest.ini_options]
markers = [
    "e2e: end-to-end tests (auto-assigned from test/e2e/)",
    "benchmark: benchmarks (auto-assigned from test/benchmark/)",
    "integration: integration tests (auto-assigned from test/integration/)",
]
```

## Make Target → Language Command Mapping

| Target             | Python                                                         | Go                                                  | TypeScript                    |
|:-------------------|:---------------------------------------------------------------|:----------------------------------------------------|:------------------------------|
| `test.unit`        | `pytest test/ -m "not (e2e or integration or benchmark)"`      | `go test -v -race -short ./internal/... ./cmd/...`  | `vitest run test/`            |
| `test.integration` | `pytest test/ -m integration`                                  | `go test -v -race -timeout 120s ./test/integration/...` | `vitest run test/integration/` |
| `test.e2e`         | `pytest test/ -m e2e`                                          | `go test -v -race -timeout 180s ./test/e2e/...`     | `vitest run test/e2e/`        |
| `test.benchmark`   | `pytest test/ -m benchmark`                                    | `go test -bench=. ./...`                            | N/A                           |
