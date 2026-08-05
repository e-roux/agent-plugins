# Duplicate Implementation Detection

Two tiers: literal (copy-paste) and structural (same logic, different names/formatting).

## Tier 1 — Literal / copy-paste duplication
**jscpd** — multi-language, fast, gives file:line clusters + similarity %.
```bash
npx jscpd . --min-lines 5 --threshold 0 --reporters json --output ./audit-out
```
Read `./audit-out/jscpd-report.json` for structured clusters rather than the console output — cheaper on tokens and easier to group.

## Tier 2 — Structural / semantic duplication
Same logic, different variable names, reordered branches, different formatting — literal diff tools miss this.

- **ast-grep** — tree-sitter native, fast, good for "find all functions matching this shape" rules. Best modern default.
  ```bash
  ast-grep run -p '$FN($$$ARGS) { $$$BODY }' --lang ts
  ```
- **semgrep** — similar structural matching, larger rule ecosystem, slightly heavier.
- **PMD CPD** (token-based) — older but still solid for multi-language legacy codebases, especially Java/C-family.

## Workflow
1. Run jscpd first — cheap, catches the bulk of duplication (copy-pasted blocks, boilerplate).
2. For anything jscpd misses that "feels" duplicated (user points at two files, or a dead-code pass flags near-identical exports), write a targeted ast-grep pattern for the shape in question.
3. Before proposing a merge: summarize both implementations' actual differences to the user. Identical-looking code can have subtly different edge-case handling (null checks, error paths) — don't silently unify.

## Output shape to feed back to the model
Collapse to: `cluster_id, files[], lines[], similarity%, snippet_preview(~3 lines)`. Never paste full duplicated blocks from both sides into context — a 3-line preview is enough to triage.
