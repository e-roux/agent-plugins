# Test Assessment and LLM-as-a-Judge

## Assessment Is Part of Testing

Do not stop at "tests pass." Assess whether the tests are strong enough to detect the regression or behavior you care about.

Use three layers, in order:

1. **Executable checks**: the tests run, fail when expected, pass after the fix, and satisfy repo linting and coverage gates
2. **Human-readable quality checks**: the tests are understandable, precise, diagnostic, and not overfit to implementation details
3. **LLM-as-a-judge**: a rubric-driven judge scores test quality or compares candidate tests when the qualitative judgment is hard to automate with ordinary tools

LLM-as-a-judge complements execution, linting, and coverage. It does not replace them.

## What Good Tests Demonstrate

Assess against these dimensions:

- **Behavior coverage**: public behaviors, invariants, boundary values, invalid input, and error paths are exercised
- **Assertion quality**: assertions are specific, meaningful, and fail with useful messages
- **Regression power**: the test would catch a realistic bug, not just confirm the current implementation
- **Isolation and determinism**: minimal hidden state, stable fixtures, controlled clocks/randomness/network
- **Maintainability**: clear setup, low duplication, and minimal incidental detail

## When To Use LLM-as-a-Judge

Use it when you need help answering questions like:

- "Are important failure modes still untested?"
- "Which of these two tests is more likely to catch a regression?"
- "Does this test file look complete but quietly miss behaviors?"
- "Are the assertions strong enough, or are they superficial?"

Prefer:

- **single-output scoring** for "is this test good enough?"
- **pairwise comparison** for "which candidate test is better?"

## Inputs for the Judge

Provide the judge with:

- the source code or the behavior/specification being tested
- the test file or candidate test files
- test runner output
- lint output
- coverage output or uncovered lines, when available
- any known constraints, mocks, fixtures, or shared test helpers

If the tests do not run, treat the score as failing regardless of how good they look.

## Portable Prompt Shape

Use a rubric with explicit scoring rules and require reasons tied to evidence.

```text
You are evaluating automated tests.

Inputs:
- Source or behavior description
- Test file(s)
- Test runner, lint, and coverage evidence

First, decide whether executable gates pass.
If the tests do not run or the evidence shows invalid assumptions, return a failing score.

Then score the tests on:
1. behavior coverage
2. assertion quality
3. regression power
4. maintainability

Scoring rules:
- 0.0: tests do not run, are invalid, or miss the core behavior
- 0.25: some useful intent, but major gaps or weak assertions
- 0.5: adequate baseline, but important paths or diagnostics are missing
- 0.75: strong tests with minor blind spots
- 1.0: strong executable tests with convincing coverage, assertions, and regression power

Return:
- overall score
- per-dimension scores
- missing cases
- false-confidence risks
- short rationale citing concrete evidence
```

## Judge Limitations and Mitigations

Known issues:

- **Non-determinism**: scores vary slightly across runs
- **Verbosity bias**: judges may over-reward long tests or long explanations
- **Execution blindness**: a test can read well but still not run
- **Model self-preference / position bias**: especially in pairwise comparisons

Mitigate by:

- checking execution, lint, and coverage before judging
- using coarse rubrics or binary gates for critical requirements
- randomizing candidate order in pairwise comparisons
- asking for missing cases and evidence, not just a scalar score
- aggregating scores over batches instead of over-trusting one sample

## Language-Specific Evidence Examples

- **Python**: `pytest` results, marker-specific runs, coverage summaries, and lint/type output behind `make`
- **Go**: `go test` results, race detector output, coverage output, and integration/e2e gating signals
- **TypeScript**: `vitest` or `jest` results, coverage summaries, and lint/type output behind `make`

Keep the workflow language-agnostic in `SKILL.md`; only use language-specific signals when they improve the evidence available to the judge.
