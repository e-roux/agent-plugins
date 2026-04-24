---
name: git-commit
description: Commit workflow guidelines including message format, quality gates, and staging strategies.
---

# Git Commit

## Quality gate

**BLOCKING** — enforced by the `qa-gate-guard` hook.

If a `Makefile` exists at the repository root, `git commit` is **denied** unless `make qa` passes with zero errors. This is non-negotiable regardless of error origin.

```sh
[ -f Makefile ] && make qa
```

## Commit message format

Two-step scoped conventional commit:

```
<type>(<scope>): <short imperative summary>

<body: why this change is necessary, in plain prose, ≤72 chars/line>
```

- `type`: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `perf`, `ci`
- `scope`: slash-delimited path from component to subcomponent
  (e.g. `zsh/completions`, `pi/agent`, `nvim/lsp`, `makefile`)
- Summary: imperative, lowercase, no period, ≤72 chars
- Body: optional when summary is self-evident; otherwise explain the
  motivation or constraint that drove the change

Examples:

```
fix(pi/agent): fall back to bunx when npm cache is cold

Some corporate proxies block bun's native package fetcher but allow
npm's registry client, making bunx the safer fallback path.
```

```
feat(zsh/completions): add pi completion with dynamic provider list

Completion round-trips to providers at tab-time to stay accurate
without manual maintenance.
```

## Workflow

1. You MUST be on a feature, fix or specific branch. DO NOT COMMIT FROM main
2. Run `make qa` if `Makefile` exists; abort on failure.
3. Infer from the prompt if the user provided specific file paths/globs and/or additional instructions.
4. Review `git status` and `git diff` to understand the current changes (limit to argument-specified files if provided).
5. (Optional) Run `git log -n 50 --pretty=format:%s` to see commonly used scopes.
6. If there are ambiguous extra files, ask the user for clarification before committing.
7. Stage only the intended files (all changes if no files specified).
8. Run `git commit -m "<subject>"` (and `-m "<body>"` if needed).

## Notes

- Body is OPTIONAL. If needed, add a blank line after the subject and write short paragraphs.
- Do NOT include breaking-change markers or footers.
- Do NOT add sign-offs (no `Signed-off-by`).
- Only commit; do NOT push.
- If it is unclear whether a file should be included, ask the user which files to commit.
- Treat any caller-provided arguments as additional commit guidance. Common patterns:
  - Freeform instructions should influence scope, summary, and body.
  - File paths or globs should limit which files to commit. If files are specified, only stage/commit those unless the user explicitly asks otherwise.
  - If arguments combine files and instructions, honor both.
