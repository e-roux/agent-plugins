---
name: codebase-audit
description: "Use this skill to find dead code and unused exports/symbols, detect duplicate or near-duplicate implementations, measure code complexity/entropy/bloat, or locate a symbol/function/class in a codebase. Triggers on requests to audit, clean up, de-duplicate, or track code-quality trends — including vague phrasing like 'this repo feels bloated' — and on quick symbol-lookup requests like 'where is X defined'."
---

# Codebase Audit — Cleanup, Duplication & Entropy

A skill for auditing a codebase for dead code, duplicate implementations, and structural entropy/bloat, and for quickly locating symbols — while staying token-efficient by doing the heavy lifting with local CLI tools and only feeding the model compact, structured findings rather than raw files.

## Core principle: tools first, model second

Never read whole files into context to "look for" dead code, duplicates, or complexity by eye. Always:

1. Run the appropriate CLI tool(s) below.
2. Collapse output to a `file:line, symbol, tool, confidence` findings table (or a metrics table for entropy).
3. Only then reason over the table, and only pull in the specific file snippets needed to act on a given finding.

This keeps 90%+ of the analysis outside the context window.

## Decide which mode the user needs

| User wants | Go to |
|---|---|
| Find unused/unreachable code (cleanup) | `references/dead-code.md` |
| Find copy-paste or structurally similar code | `references/duplicates.md` |
| Quickly find a symbol/function/definition/usages | `references/symbol-search.md` |
| Measure or track complexity, bloat, churn, coupling, entropy trend | `references/entropy.md` |
| Full repo audit (all of the above) | Run all in sequence, see below |

## Quick full-audit workflow

```bash
# 1. Scope the repo
tokei .                     # LOC by language — tells you what tools to run

# 2. Dead code (pick tool per language — see references/dead-code.md)

# 3. Duplication
npx jscpd . --min-lines 5 --threshold 0 --reporters json --output ./audit-out

# 4. Structural duplication / custom pattern search
ast-grep scan                # if a project sgconfig.yml exists, else ast-grep run -p '<pattern>'

# 5. Complexity, coupling, churn, composite entropy score — see references/entropy.md

# 6. Python-specific Type Annotation Footprint & Density (for Python repos)
uv run skills/codebase-audit/scripts/strip_annotations.py .
```

Or run `scripts/audit.sh <path>` (bundled with this skill) to chain scoping, dead-code, duplication, complexity, coupling, churn, and the composite entropy score into a single JSON findings report.

Then:

1. Load the JSON/text findings (not the source files) into context.
2. Group/prioritize findings, flag anything with "maybe dead" or ambiguous confidence.
3. For anything about to be deleted, verify with an LSP `references` check (see `references/symbol-search.md`) before proposing a diff.
4. Present a short prioritized list to the user before making any edits — do not mass-delete on the first pass.
5. For entropy/complexity, report the **trend** (before/after, or vs. the previous commit/PR), not just a snapshot — see `references/entropy.md`.

## Modern Language Conformance

To prevent technical debt and legacy creep, codebase audits must verify that codebases conform to modern language standards:

- **Active Versions Only**: Codebases must avoid legacy or end-of-life (EOL) language runtimes and compilers. Projects must use one of the last three major releases of a language and prefer at least the penultimate version.
  - *Python*: Target `Python >=3.13` (avoid pre-3.11/3.12 syntax; utilize modern features like PEP 695 generic type parameters).
  - *Golang*: Target `Go >=1.26` (or latest active minor version).
  - *JavaScript/Node.js*: Target `Node >=26` (or latest active LTS).
- **Anti-Legacy Patterns**: Flag deprecated standard library usage, legacy modules (e.g. `distutils` in Python or legacy CommonJS `require` where ES Modules are standard), and construct choices superseded by modern primitives.
- **Adopt Modern Language Features**: Actively promote and migrate code to contemporary syntax and idioms provided by the target language version:
  - *Python >=3.13*: Prefer modern built-in collections for type hinting (e.g. `list[str]` instead of `typing.List[str]`), PEP 695 generic parameter lists (`def func[T](x: T):` instead of `T = TypeVar('T')`), structural pattern matching (`match/case`), and native exception groups.
  - *Golang >=1.26*: Prefer standard generic type declarations, structured logging (`slog`), native error-wrapping (`errors.Join`), and modern standard library primitives.
  - *JavaScript/Node.js >=26*: Prefer native ECMAScript modules (ESM), modern syntax (async/await, optional chaining, nullish coalescing), native Web APIs (like `fetch`), and native promise-based APIs (`node:fs/promises`).

## Separation of Concerns (SoC) & Architectural DRYness

Auditing structural entropy is not just about locating copy-pasted blocks (literal DRY) or measuring Cyclomatic Complexity; it must also actively identify violations of architectural boundaries (Separation of Concerns) and infrastructure DRYness:

- **Strict Layered Isolation (SoC)**:
  - *Thin Handlers & Controllers*: Enforce that API gateways, web route orchestrators, and network handlers remain strictly "thin." They must contain zero inline business or data-access logic, delegating instead to dedicated domain services.
  - *No Direct Data Operations*: Flag any occurrence of inline SQL query strings, raw database drivers, or untyped connections directly in application handlers. Instead, mandate type-safe query builders or abstraction repositories (e.g., using `Kysely` for type-safe SQL construction in TypeScript, or language-specific equivalent query builders/ORMs).
- **Single Source of Truth for Infrastructure (DRY)**:
  - *Declarative Schema Migration*: DB-backed applications must maintain exactly one centralized migration pipeline (e.g., using `Atlas` for declarative schema management, or single tool sets like `alembic` or `golang-migrate`). Flag and prohibit split migrations, manual raw SQL scripts, or ad-hoc database mutation bypasses.
  - *Eliminate Cross-Tier Leaks*: Identify and flag leaky abstractions—such as direct imports of database models or database connection clients into presentation/UI components, or presentation layer concerns (like raw HTTP response objects) leaking into core domain logic.
  - *Cross-Cutting Infrastructure Decorators*: When deduplicating identical boilerplate (e.g., caching, retries, logging) across multiple provider clients, prefer structural Decorators/Proxies (Composition over Inheritance) to keep concrete clients 100% focused on their primary domain concern (SRP).
  - *Consolidated Resource-Safe Wrappers*: If multiple modules consume the same third-party library (e.g., PDF rendering, file I/O, serializers), consolidate calls into a central, exception-safe utility module. Ensure proper resource closure (using generators/context managers) to avoid resource leaks under exception paths.
  - *No Inline Schema Mutators*: Flag and prohibit running structural database DDL statements (e.g., `ALTER TABLE`, `CREATE INDEX`, `ADD COLUMN`) dynamically during application initialization or connection pool setups. Schema mutations must be orchestrated via centralized, single-instance migration runners executed prior to application startup.

## Technical Hygiene & Test Isolation

Auditing a repository also means validating that testing setups are robust, resource-safe, and free of environmental leaks or structural barriers:

- **Explicit Resource Teardown in Test Fixtures**:
  - In unit tests (such as `pytest` fixtures), verify that any spawned files, sockets, process pools, or connection handles (e.g., SQLite connections, `diskcache` instances, HTTP clients) are closed explicitly during fixture teardown.
  - *Rationale*: Relying on Python`s garbage collection (`gc.collect()`) to implicitly close database files or sockets causes resource leaks, file descriptor exhaustion under parallel testing (e.g. `xdist`), and generates disruptive `ResourceWarning` noise in test outputs.
  - *Remediation*: Enforce the use of generator-based test fixtures (`yield`) where resource-closing methods (e.g., `cache.close()`, `conn.close()`) are executed reliably in the teardown phase.
- **Algorithmic Isolation for Dependency-Heavy Parsers**:
  - For parsers, models, or clients that show low test coverage due to heavy binary or external cloud dependencies (such as Tesseract, openpyxl, Azure DI, or remote LLMs), verify that pure algorithmic utility logic is isolated.
  - *Rationale*: If layout algorithms, text cleaning helpers, header-stripping logic, or normalization calculations are coupled directly with external I/O execution, they cannot be tested offline, leading to silent regressions and 0% coverage on critical helper functions.
  - *Remediation*: Enforce separation of pure algorithmic utility functions (e.g., normalizers, clean_cells, grid consolidators) from extraction and I/O tasks, allowing them to be covered by 100% offline, mock-backed unit tests.
- **Gradual Failure Degradation (Robustness & Fallbacks)**:
  - Verify that critical structured extraction engines do not fail hard immediately upon a schema validation failure.
  - *Rationale*: Minor validation failures under complex schemas can cause 500 exceptions, even when a larger, more capable model could recover the extraction easily.
  - *Remediation*: Mandate cascading retry schemas: first run secondary self-correction (re-asking), and if schema validation continues to fail, escalate to a highly capable reasoning model fallback chain before raising an application error.

## Guardrails

- Static dead-code tools have false positives from dynamic dispatch, reflection, string-based lookups (e.g. route tables, DI containers, test fixtures picked up by name). Always mark these "needs LSP/manual verification" rather than proposing deletion outright.
- Flag "Production-Dead" code—symbols or helpers that have 100% test coverage but 0% production usage. Do not just move them to tests; if private, delete them and their tests; if public helpers used for mock seeding/setup, inline or relocate them directly into `test/` (e.g., `conftest.py`).
- For duplication findings, don't auto-merge — summarize the two implementations' differences to the user first (behavior can subtly diverge even when code looks identical).
- Prefer the most current tool per language (see `references/dead-code.md`) over writing a bespoke tree-sitter script — dedicated tools handle edge cases (re-exports, decorators, test-only usage) that a quick script won't.
- Entropy/complexity metrics are directional signals, not verdicts. Don't block a change on a single composite number — track the delta over time and let the user weigh trade-offs (e.g. churn without payoff may just mean an area is genuinely evolving).
- When auditing an LLM-authored change (PR, commit range), always compare **before vs. after**, not the absolute score — see the "LLM-authored change" workflow in `references/entropy.md`.

## Reference files

- `references/dead-code.md` — per-language dead code / unused export tools, install commands, known false-positive patterns
- `references/duplicates.md` — literal (jscpd) vs structural (ast-grep/semgrep/PMD CPD) duplicate detection, when to use which
- `references/symbol-search.md` — ripgrep / ctags / ast-grep / LSP / Sourcegraph tiers, from "know the exact name" to "know only the behavior"
- `references/entropy.md` — complexity, bloat, churn, coupling metrics; composite entropy score; before/after workflow for AI-assisted PRs
- `references/heuristics.md` — architectural file-naming conventions, layout rules, and projectionist-style bidirectional source-to-test mapping heuristics

## Bundled scripts

- `scripts/audit.sh` — chains tokei → dead-code tool (auto-detected by language) → jscpd → complexity (lizard/radon) → coupling (madge/pydeps/go mod graph) → git churn → composite entropy score, writing `audit-findings.json` and `entropy.json`
- `scripts/strip_annotations.py` — parses Python AST, extracts type annotations to calculate 'static-typing density' and character footprint metrics, and optionally strips annotations (variable, parameter, return, type parameter bounds, type comments) from the codebase.
