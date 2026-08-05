# Dead Code Detection — per language

Static tools first; LSP `references` check as the accuracy backstop before deleting anything.

## JavaScript / TypeScript
- **knip** — current standard, replaced ts-prune. Finds unused files, exports, dependencies, and types in one pass.
  ```bash
  npx knip
  npx knip --reporter json > knip-findings.json
  ```
- False positives: barrel-file re-exports, framework-magic entry points (Next.js pages, Nuxt), test-only exports. Configure `knip.json` `entry`/`ignore` fields for these.

## Python
- **vulture** — heuristic-based, fast, works without a full type-checked build.
  ```bash
  vulture . --min-confidence 80
  ```
- **ruff** — `F401` (unused import), `F841` (unused local variable) are near-zero false positive and very fast; good first pass.
  ```bash
  ruff check --select F401,F841 .
  ```
- False positives: dynamic attribute access (`getattr`), Django/Flask route decorators, pytest fixtures, `__all__` exports.

## Go
- **deadcode** (`golang.org/x/tools/cmd/deadcode`) — whole-program analysis, very low false-positive rate because it uses the compiler's own call graph.
  ```bash
  go install golang.org/x/tools/cmd/deadcode@latest
  deadcode ./...
  ```

## Rust
- `cargo +nightly udeps` — unused dependencies.
- Compiler's own `dead_code` lint (`#[warn(dead_code)]`, on by default) — catches unused private items; run `cargo build` and grep warnings.

## Multi-language fallback
- **ast-grep** — tree-sitter powered, write a structural rule like "identifier declared, zero references in file" for languages without a dedicated tool.
- Generic but coarser: `rg` for a symbol name across the repo, count matches — if count is 1 (the declaration itself), it's a dead-code candidate. Cheap but noisy; only use as a first triage pass, always verify with a real tool or LSP after.

## Verifying "maybe dead" findings before deleting
Any flagged symbol should be checked with an LSP `textDocument/references` call (or your editor's "Find All References") before removal — string-based dispatch, reflection, and dynamic imports are invisible to the static tools above. See `symbol-search.md` for how to script this.
