---
name: git
description: Version control operations including commits, pull requests, and branch management. Use when handling git operations, commits, pull requests, or version control workflows.
---

# Git Operations

## Overview

This skill provides workflows for common git operations with focus on communication quality and code review readiness. Operations are organized by subcommand type.

## Core Principles
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

## Git Subcommands

For detailed workflows and guidelines by operation, see the relevant resource file:

- **`git commit`** → See [resources/git-commit.md](resources/git-commit.md)
- **Pull requests** → See [resources/git-pull-request.md](resources/git-pull-request.md)

**MANDATORY**: When the user requests a commit or pull request, you MUST read the corresponding resource file to ensure you follow the complete workflow and formatting requirements.
