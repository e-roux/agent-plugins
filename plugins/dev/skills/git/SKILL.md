---
name: git
description: Version control operations including commits, pull requests, and branch management. Use when handling git operations, commits, pull requests, or version control workflows.
---

# Git Operations

## Overview

This skill provides workflows for common git operations with focus on communication quality and code review readiness. Operations are organized by subcommand type.

## Core Principles

### Branch-First Workflow

**MANDATORY — before any file changes in a git repository:**

1. Check current branch: `git branch --show-current`
2. If on `main`/`master`, you MUST create and switch to a feature branch:
   ```sh
   git checkout -b <type>/<descriptive-slug>
   ```
3. Branch naming: `feat/`, `fix/`, `chore/`, `docs/`, `refactor/`, `test/` prefix + kebab-case slug
4. Only then begin making changes

The `branch-first-guard` hook mechanically enforces this — `edit`/`create` calls are denied on `main`/`master`.

### Communication Style

- No emoji in commit bodies. Small Unicode symbols (·, →, ✗, ✓) acceptable only when they add meaning.
- Describe **why**, not what. Avoid listing files, test counts, or implementation steps.
- Titles and bodies must be concise and technical.

### Quality Gate

Always run the quality gate before committing if applicable:

```sh
[ -f Makefile ] && make qa
```

Do not proceed if it fails. Fix issues first.

If a pull requests is emitted:
- the pull request must be merged into the target branch,
- the target branch must be selected and the git status must be clean
- the feature branch can then be safely be removed
- if relevant and if not closed, the issue must be closed

## Tool Routing

When MCP git-ops tools are available, ALWAYS prefer them over bash equivalents.
If an MCP tool fails, fall back to the bash command shown in the table.

| Operation | MCP tool | Bash fallback |
|-----------|----------|---------------|
| Push | `mcp__git-ops__push` | `git push origin <branch>` |
| Create PR/MR | `mcp__git-ops__create_pr` | `gh pr create` / `glab mr create` / `az repos pr create` |
| Merge PR/MR | `mcp__git-ops__merge_pr` | `gh pr merge` / `glab mr merge` / `az repos pr update --status completed` |
| PR status | `mcp__git-ops__pr_status` | `gh pr view` / `glab mr view` / `az repos pr show` |

MCP tools auto-detect the platform and enforce branch protection.
Raw bash commands bypass these guards (except the existing branch-guard in hooks).

## Git Subcommands

For detailed workflows and guidelines by operation, see the relevant resource file:

- **`git commit`** → See [resources/git-commit.md](resources/git-commit.md)
- **Pull requests** → See [resources/git-pull-request.md](resources/git-pull-request.md)

**MANDATORY**: When the user requests a commit or pull request, you MUST read the corresponding resource file to ensure you follow the complete workflow and formatting requirements.
