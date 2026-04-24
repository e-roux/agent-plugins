---
name: git-pull-request
description: Pull request workflow including branch safety, quality gates, commit format, and PR body guidelines.
---

# Pull Requests

## Communication style

- No emoji in PR bodies. Small Unicode symbols (·, →, ✗, ✓) are
  acceptable only when they add meaning.
- Describe **why**, not what. Avoid listing files changed, test counts, or
  implementation steps.
- Titles and bodies must be concise and technical.

## Quality gate

**BLOCKING** — enforced by the `qa-gate-guard` hook.

If a `Makefile` exists at the repository root, `git commit` is **denied** unless `make qa` passes with zero errors. This is non-negotiable regardless of error origin.

**Warnings are not optional.** Do not silently ignore warnings emitted by `make qa`. Fix them when feasible — they indicate real issues. Only skip a warning fix when it is genuinely infeasible (e.g., upstream dependency, false positive from a third-party tool). In that case, state which warning you are skipping and why.

```sh
[ -f Makefile ] && make qa
```

## Branch safety

- Target branch for PRs: `devel` if it exists, otherwise `main`.

```sh
# Determine PR target — grep output, not exit code (ls-remote exits 0 even on no match)
if git ls-remote --heads origin devel | grep -q refs/heads/devel; then
  TARGET=devel
else
  TARGET=main
fi
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

1. Verify current branch is not `main`.
2. Run `make qa` if `Makefile` exists; abort on failure.
3. Add the most significant change to `CHANGELOG.md`. Only top bullet are allowed. Be very concise.
4. Stage changes (`git add`). There should be only `CHANGELOG.md`.
5. Draft commit message following the format above.
6. Commit.
7. Determine PR target branch.
8. Push branch to origin.
9. Open the PR/MR — prefer MCP tool, fall back to CLI:

   **MCP (preferred):** Call `mcp__git-ops__create_pr` with `title`, `body`,
   and `target_branch` set to `$TARGET`. The tool auto-detects the platform.

   **Bash fallback** (if MCP unavailable):
   ```sh
   REMOTE_URL=$(git remote get-url origin)
   BRANCH=$(git branch --show-current)

   if echo "$REMOTE_URL" | grep -qE 'github\.com'; then
     gh pr create --base "$TARGET" --title "<title>" --body "<body>"
   elif echo "$REMOTE_URL" | grep -qE 'dev\.azure\.com|visualstudio\.com'; then
     az repos pr create --target-branch "$TARGET" --title "<title>" --description "<body>"
   else
     glab mr create \
       --source-branch "$BRANCH" \
       --target-branch "$TARGET" \
       --title "<title>" \
       --description "<body>" \
       --remove-source-branch
   fi
   ```

   - **Title/--title**: same as commit subject line
   - **Body/--description**: same as commit body, plus a `## Context` section
     if additional background is useful; no bullet lists of changed files.

## PR body template

```
<why this change is necessary>

## Context  ← omit if body already covers it
<additional background, constraints, or references>
```
