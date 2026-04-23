# Feature: Git Workflow Guards

## Context

Agents can silently edit files on protected branches (`main`, `master`), producing
dirty working trees that bypass the PR review cycle. This happened in practice when
an agent edited the installed plugin copy instead of the source repo — both on `main`.

The existing `branch-guard` only blocked `git push/merge ... main` but not the
preceding edits, so damage was done before the guard could fire.

## Acceptance Criteria

- [ ] AC-001: `edit`/`create` tool calls MUST be denied when the target file resides in a git repository whose current branch is `main` or `master`
- [ ] AC-002: `bash` tool calls that write to files (`echo >`, `cat >`, `tee`, `sed -i`) MUST also be denied when current branch is `main` or `master`
- [ ] AC-003: The denial message MUST instruct the agent to create a feature branch with the naming convention `<type>/<descriptive-slug>`
- [ ] AC-004: **Claude Code**: `UserPromptSubmit` hook MUST inject branch status context before every turn, so the model knows its branch before deciding what tools to call
- [ ] AC-005: **Copilot CLI**: Session-start context MUST inject a mandatory branch-first workflow reminder
- [ ] AC-006: The `git` skill MUST document the branch-first workflow as its first core principle
- [ ] AC-007: The `dev` skill guard table MUST list `branch-first-guard` with tools `edit`/`create`/`bash`

## Constraints

- The guard fires on every `edit`/`create` — keep it fast (single `git rev-parse` call)
- Must not block edits to files outside any git repository (e.g., `/tmp` scratch files)
- Must not block `bash` tool calls (those are handled by the existing `branch-guard`)

## Non-Goals

- Enforcing a specific branch naming convention at the hook level (discipline, not guard)
- Blocking reads (`view`, `grep`, `glob`) on protected branches — read access is always allowed
