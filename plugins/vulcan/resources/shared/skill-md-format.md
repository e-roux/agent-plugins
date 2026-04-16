# SKILL.md File Reference

Skills are task-specific instruction modules. Each skill lives in its own named subdirectory containing a `SKILL.md` file and optional supplementary resources.

## Directory Structure

```
skills/
├── webapp-testing/
│   └── SKILL.md
└── deploy/
    ├── SKILL.md
    └── deploy-script.sh      # Supplementary resources
```

## SKILL.md Format

```markdown
---
name: webapp-testing
description: Guide for testing web applications. Use when asked to write or debug tests.
---

When writing tests for this project:

1. Use Vitest as the test runner
2. Place tests adjacent to source files with `.test.ts` suffix
3. Mock external APIs using msw
4. Run `npm test` to verify before committing
```

## Frontmatter Fields

| Field         | Required | Description                                              |
|---------------|----------|----------------------------------------------------------|
| `name`        | yes      | Lowercase with hyphens, typically matches directory name |
| `description` | yes      | Tells Copilot when to load this skill                    |
| `license`     | no       | License for the skill                                    |

Skills can include supplementary files (scripts, examples, configs) referenced in the instructions. Copilot can read these files when the skill is active.

## Skills CLI Commands

| Command                    | Description                               |
|----------------------------|-------------------------------------------|
| `/skills list`             | List available skills                     |
| `/skills reload`           | Reload skills added during the session    |
| `/skills add`              | Add an alternative skills location        |
| `/skills remove DIR`       | Remove a directly-added skill directory   |
| `/skills info`             | Details about a skill (location, plugin)  |
| `/skills`                  | Toggle skills on/off interactively        |

Since CLI v1.0.17, `/skills list` also includes CLI-shipped built-in skills. The filesystem
location table below covers the skills you can author, distribute, and version-control yourself.

## Invoking a Skill Explicitly

Include the skill name preceded by `/` in your prompt:

```
Use the /webapp-testing skill to write tests for the auth module.
```

## Skills vs Custom Instructions

Use **`AGENTS.md`** (or `.github/copilot-instructions.md`) for simple guidance that applies to almost every task (coding standards, repo conventions). Use **skills** for detailed task-specific instructions that the agent should only load when relevant.

## Skill Locations

| Location                       | Scope    | Portability     |
|--------------------------------|----------|-----------------|
| `.agents/skills/`             | Project  | **Portable**    |
| `.github/skills/`             | Project  | GitHub          |
| `.claude/skills/`             | Project  | Claude Code     |
| `~/.agents/skills/`           | Personal | **Portable** (v1.0.11+, aligns with VS Code GHCP4A) |
| `~/.copilot/skills/`          | Personal | GitHub          |
| `~/.claude/skills/`           | Personal | Claude Code     |
| Plugin `skills/` dirs          | Plugin   | GitHub          |

**Recommendation:** Use `.agents/skills/` for maximum portability — it works across copilot-cli, Claude Code, and VS Code. The SKILL.md format is identical regardless of location.

Project skills take precedence over plugin skills (first-found-wins, deduplicated by name).

For the full loading order, see `resources/shared/loading-precedence.md`.
For skill writing best practices, see `resources/shared/skill-writing-guide.md`.
