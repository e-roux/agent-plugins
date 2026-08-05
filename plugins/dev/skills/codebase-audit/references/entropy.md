# Code Entropy & Complexity Tracking

Entropy here means accumulated disorder: duplication, dead code left behind, unwarranted verbosity,
rising structural complexity, high-churn/low-payoff files, and tangled dependencies. Track it as a
**trend over commits/PRs**, not a one-off snapshot — a single absolute number is rarely actionable.

## Signal → metric → tool

| Signal | Metric | Tool |
|---|---|---|
| Duplication | % of lines in near-duplicate clusters | `jscpd` (see `duplicates.md`) |
| Dead code accumulation | count/ratio of unused exports/functions over time | `knip`, `vulture`, `deadcode` (see `dead-code.md`) |
| Verbosity/bloat | LOC per function/feature vs. a baseline | `tokei`, `scc`, or diff LOC against a prior commit for the same feature |
| Typing Verbosity / Bloat | Type Annotation Density (character footprint %) | `scripts/strip_annotations.py` (Python) |
| Structural complexity | cyclomatic complexity, nesting depth | `lizard` (multi-language), `radon` (Python), ESLint `complexity` rule (JS/TS) |
| Churn without payoff | files with high edit frequency but low net functionality | `git log --stat` + churn tools (e.g. `git-churn`, `code-maturity`) |
| Coupling/entanglement | how tangled the dependency graph is | `madge` (JS/TS), `pydeps` (Python), `go mod graph` (Go) |

### Install / run cheatsheet

```bash
# Verbosity / bloat / annotations
brew install tokei scc
tokei .                                    # LOC by language, fast triage
scc .                                      # LOC + complexity + cost estimate
uv run skills/codebase-audit/scripts/strip_annotations.py .  # Measure annotation density and footprint (Python)

# Structural complexity
pip install lizard radon                  # lizard: multi-language; radon: Python-specific
lizard . --CCN 10                          # flag functions over cyclomatic complexity 10
radon cc . -s -a                           # Python cyclomatic complexity, sorted, with average
# JS/TS: add `"complexity": ["warn", 10]` to .eslintrc and run `eslint .`

# Coupling / entanglement
npx madge --circular --extensions ts,tsx,js,jsx .   # JS/TS: circular deps + graph
pip install pydeps && pydeps mypackage --max-bacon 2 # Python
go mod graph                                          # Go: module dependency graph

# Churn without payoff
git log --since="90 days ago" --format=format: --name-only -- . \
  | sort | uniq -c | sort -rg | head -20    # most-edited files
```

## Composite entropy score

Most teams don't chase one number — they track a small dashboard over time. If a single score is
useful (e.g. as a CI gate trend line), a reasonable starting formula is:

```
entropy_score ≈ w1*(duplication %)
              + w2*(dead_code %)
              + w3*(avg cyclomatic complexity)
              + w4*(LOC growth rate vs. feature count)
```

- Weights (`w1..w4`) and normalization are project-specific — start with equal weights, then tune
  based on what actually correlates with review pain/bugs in this repo.
- Normalize each term to a comparable 0–100 scale before weighting (e.g. duplication % is already
  0–100; cyclomatic complexity needs a project-specific ceiling, e.g. `min(avg_ccn / 20, 1) * 100`).
- Store the score **per commit/PR**, not just the latest value, so the dashboard shows a trend line.
- Treat the score as a triage signal to start a conversation, not a merge-blocking verdict on its own.

## LLM-authored change: measure the delta, not the snapshot

Because LLM-introduced entropy is what you're usually trying to catch, the useful measurement is the
**before/after delta** across a PR or commit range, not an absolute number:

1. Run the metrics above on the base branch (before the AI-assisted change).
2. Run the same metrics on the PR branch (after the change).
3. Diff them:
   - did duplication % go up?
   - did dead code get left behind (new unused exports/functions)?
   - did LOC grow faster than the feature warranted? (compare against a hand-written baseline PR of
     similar scope if one exists)
   - did average/max cyclomatic complexity per function increase?
   - did coupling increase (new circular deps, wider fan-out)?
4. Report the deltas as a compact table — do not paste full before/after file contents into context.

This turns entropy tracking into a regression check that can run in CI on every AI-assisted PR:
compute metrics on `main` and on the PR branch, fail (or just annotate) the PR with the delta table
when a threshold is crossed (e.g. duplication +5pp, new dead exports > 0, avg CCN +2).

## Practical workflow

1. **Baseline**: run `scripts/audit.sh` (or the cheatsheet above) once on the base branch/tag and save
   `entropy.json` as the reference point.
2. **Per PR/commit**: re-run and diff against the baseline. Keep an append-only log (one JSON line per
   commit) rather than overwriting — this is what makes the trend visible.
3. **Present a dashboard, not a single number**: duplication %, dead-code count, avg complexity, churn
   hotspots, coupling — each with its own trend line — plus the composite score if one is configured.
4. **Act on sustained trends**, not single-commit noise: a one-off complexity bump in a hotfix matters
   less than three consecutive PRs each raising duplication and complexity together.
