# Skill Writing Guide

Best practices for writing effective skills. Applies to project-local skills, plugin skills, and SDK skill directories.

Inspired by patterns from [anthropics/skills](https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md), adapted for tool-agnostic use across copilot-cli, Claude Code, VS Code, and the Copilot SDK.

## Progressive Disclosure

Skills use a three-level loading system. Understanding this helps you decide what goes where:

| Level | What | When loaded | Size guidance |
|-------|------|-------------|---------------|
| **Metadata** | `name` + `description` frontmatter | Always in context | ~100 words |
| **SKILL.md body** | Markdown instructions | When the skill triggers | <500 lines ideal |
| **Bundled resources** | scripts/, references/, assets/ | On demand (read by agent) | Unlimited |

The description drives triggering — it's always visible. The body is injected when the skill activates. Bundled resources are read only when the instructions say to.

## Anatomy of a Skill Directory

```
skill-name/
├── SKILL.md              # Required — frontmatter + instructions
├── scripts/              # Executable code for deterministic tasks
│   └── validate.sh
├── references/           # Docs loaded into context as needed
│   ├── aws.md
│   └── gcp.md
└── assets/               # Templates, schemas, config files
    └── template.json
```

Reference files clearly from SKILL.md with guidance on **when** to read them. For large reference files (>300 lines), include a table of contents.

### Domain Organization

When a skill supports multiple domains or frameworks, organize by variant:

```
cloud-deploy/
├── SKILL.md              # Workflow + framework selection logic
└── references/
    ├── aws.md            # Read only when deploying to AWS
    ├── gcp.md
    └── azure.md
```

The agent reads only the relevant reference file, keeping context lean.

## Writing Effective Descriptions

The `description` field is the primary triggering mechanism. The agent sees all skill descriptions and decides which to load based on relevance to the user's prompt.

### Be Specific and "Pushy"

Agents tend to under-trigger skills — they skip skills that would be helpful. Combat this by making descriptions specific about **when** to use the skill, not just **what** it does.

**Weak:**
```yaml
description: Guide for building dashboards
```

**Strong:**
```yaml
description: >
  Guide for building data dashboards and visualization pages.
  Use whenever the user mentions dashboards, data visualization,
  metrics display, charts, or wants to present data visually —
  even if they don't explicitly ask for a "dashboard".
```

### Description Checklist

- State what the skill does (capability)
- State when to use it (trigger phrases, contexts, adjacent concepts)
- Include terms users might use informally ("make a chart" → visualization skill)
- Keep all "when to use" info in the description, not in the body

## Writing Instructions

### Explain the Why

Modern LLMs respond better to reasoning than to rigid rules. Explain **why** something matters rather than piling on constraints.

**Rigid (less effective):**
```markdown
ALWAYS use semantic versioning. NEVER use date-based versions.
```

**Reasoned (more effective):**
```markdown
Use semantic versioning (major.minor.patch) because downstream tools
parse version numbers to determine compatibility. Date-based versions
break this contract and cause dependency resolution failures.
```

If you find yourself writing ALWAYS or NEVER in all caps, reframe it as reasoning.

### Keep It Lean

Every line in SKILL.md consumes context when the skill triggers. Remove instructions that aren't pulling their weight:

- Cut boilerplate that restates what the model already knows
- Move detailed reference tables to bundled files in `references/`
- Move reusable scripts to `scripts/` instead of inlining code blocks
- If approaching 500 lines, add hierarchy and push detail into sub-files

### Use Imperative Form

Write instructions as direct commands:

```markdown
## When deploying

1. Run the test suite before building
2. Tag the release with the current version
3. Use the deploy script at `scripts/deploy.sh`
```

### Include Examples

Examples are one of the most effective ways to communicate expected behavior:

```markdown
## Commit message format

**Example 1:**
Input: Added user authentication with JWT tokens
Output: feat(auth): implement JWT-based authentication

**Example 2:**
Input: Fixed crash when database connection drops
Output: fix(db): handle connection pool exhaustion gracefully
```

### Define Output Formats Explicitly

When the skill should produce structured output, provide a template:

```markdown
## Report structure

Use this template:

# [Title]
## Executive summary
## Key findings
## Recommendations
```

## Bundle Repeated Work

If you notice that using the skill repeatedly leads to writing the same helper scripts or taking the same multi-step approach, bundle that work:

- Write the script once, put it in `scripts/`
- Reference it from the instructions: "Run `scripts/validate.sh` to check the output"
- This saves every future invocation from reinventing the wheel

## Iterative Development

Skills improve through use. A practical workflow:

1. **Capture intent** — what should the skill do, when should it trigger, what's the expected output?
2. **Draft** — write the SKILL.md with instructions and examples
3. **Test** — try representative prompts with the skill active (`/skills reload` to pick up changes)
4. **Review** — evaluate outputs. Are the instructions being followed? Is anything missing?
5. **Improve** — refine based on feedback. Generalize from specific failures rather than overfitting to test cases.
6. **Repeat** until satisfied

### Testing Tips

- Use `/skills reload` during a session to pick up changes without restarting
- Try prompts that should trigger the skill AND prompts that should NOT
- Watch for under-triggering (skill not activating when it should) — improve the description
- Watch for over-triggering (skill activating on unrelated prompts) — narrow the description
- Test with varied phrasings: formal, casual, abbreviated, different levels of detail

### Headless / Programmatic Testing

For systematic evaluation, both copilot-cli and Claude Code support headless sessions:

| Tool | Headless mode | Use for eval |
|------|---------------|--------------|
| copilot-cli | `copilot --headless --port PORT` | SDK client connects to evaluate |
| Copilot SDK | `client.createSession({ skillDirectories: [...] })` | Programmatic skill testing |
| Claude Code | `claude -p "prompt"` | Scripted prompt evaluation |

This enables A/B testing (with-skill vs without-skill) and automated assertion checking.

## Cross-Tool Compatibility

Skills written following this guide work across copilot-cli, Claude Code, VS Code, and other AI-powered tools.

**Recommended:** Use `.agents/skills/` for maximum portability. This directory is recognized by copilot-cli, Claude Code, and VS Code. Fall back to `.github/skills/` only when targeting the GitHub ecosystem exclusively.

The SKILL.md format (YAML frontmatter + Markdown body + bundled resources) is identical regardless of which directory you use.
