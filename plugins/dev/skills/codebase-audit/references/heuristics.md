# Architectural File Structure & Alternate Heuristics

Auditing structural entropy includes validating the consistency of file organization, directory layouts, and source-to-test mapping. This reference defines the naming heuristics and layout rules across different programming ecosystems to ensure high-fidelity codebase conformance.

## Core Principle: Alternates & Root Markers

Every healthy codebase exhibits structural symmetry and clear boundary separation:
1. **Root Markers**: Every module, service, or repository scope must be identified by a deterministic configuration root marker (e.g., `Makefile`, `pyproject.toml`, `package.json`, `init.lua`, or specific adjacent folders like `lua/` & `test/`).
2. **Alternate Symmetry**: Every source file must have a predictable, 1-to-1 alternate test file. The path mapping should be fully deterministic and reversible.

## Signal, Pattern, and Mapping Rules

| Ecosystem | Root Marker | Source Pattern | Alternate / Test Pattern | Test Runner / Dispatch |
|---|---|---|---|---|
| **Shell** (`zsh`/`bash`) | `zsh/config/zprofile` | `zsh/config/*` (no suffix) | `zsh/test/{}.bats` | `bats` |
| **Neovim** (`lua` config) | `nvim/config/init.lua` | `nvim/config/*.lua` | `nvim/test/unit/{}_spec.lua` | `busted` / `plenary` |
| **Neovim Plugin** | `lua/` adjacent to `test/` | `lua/*.lua` | `test/*_spec.lua` | `busted` / `plenary` |
| **Python (Mono/App)** | `pyproject.toml` | `app/*.py` | `test/{}_test.py` | `pytest` |
| **Python (Standard)** | `pyproject.toml` | `src/*.py` | `test/{dirname}/test_{basename}.py` | `pytest` |

---

## Universal Architectural Heuristics

When auditing a codebase, check for these five structural rules:

### 1. Root Marker Isolation
Verify that independent sub-packages, modules, or services in mono-repos do not leak boundary definitions. Each should have its own package/root configuration file.

### 2. Predictable Bidirectional Mapping
Every source file must map to exactly one test file. The alternate mapping must be reversible. Flag "orphaned" source files with no test counterparts, or "unpaired" test files that do not match any actual source implementation.

### 3. Unified Test-Naming Standards
Ecosystems must maintain a consistent naming schema for their test suite (choose either Prefix or Suffix, but never mix them within the same runtime environment):
- **Suffix-based**: E.g., `*.spec.ts`, `*_spec.lua`, `_test.py`.
- **Prefix-based**: E.g., `test_*.py`.

### 4. Directory Structure Mirroring
For complex, nested systems, the test directory structure must mirror the source directory structure (e.g. `src/core/auth/helper.py` <-> `test/core/auth/test_helper.py`). Flattening all nested tests into a single flat directory is a violation.

### 5. Automated Dispatch Binding
Every directory or ecosystem pattern should declare its test runner/dispatcher (e.g., `pytest`, `bats`, `cargo test`, `npm test`). Code conformance rules are only as good as the automated QA gates verifying them.
