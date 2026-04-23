---
name: project-memory
description: |
  ▎ BLOCKING: invoke this skill — do NOT use Write/Edit tools directly — when the user asks to write, capture, or document: requirements, feature specs, user stories,
  ▎ pitfalls, or lessons learned.
  Persistent agent memory for a repository — known pitfalls, lessons learned, and feature
  requirements. Use when the user mentions: requirements, specification, spec, acceptance
  criteria, pitfall, lesson learned, remember this, track mistakes, enforce lessons, add a
  pitfall, set up agent memory, component specification, feature request, or any request to
  persist knowledge across sessions. CRITICAL: requirements and specs MUST be stored in
  doc/requirements/features/<name>.md in the project repo — NEVER in session state files.
  Pitfalls go in .agents/memory/known-pitfalls.md, lessons in .agents/memory/lessons/.
---

# Project Memory Pattern

Persistent agent memory prevents the same mistakes from recurring across sessions. This pattern uses version-controlled markdown files that are injected into agent context at session start.

## Directory Structure

```
.agents/
└── memory/
    ├── known-pitfalls.md         # Accumulated pitfalls (injected at session start)
    └── lessons/                  # Individual incident files
        └── <slug>.md             # One file per incident
doc/
└── requirements/
    └── features/
        └── <feature>.md          # Acceptance criteria per feature
```

## Known Pitfalls File

`.agents/memory/known-pitfalls.md` is the primary memory artifact. It is loaded into the agent's context at session start via a `sessionStart` hook.

Pitfalls marked **[GUARDED]** are mechanically enforced by hooks. Unguarded pitfalls rely on agent discipline.

### Format

```markdown
# Known Pitfalls

Lessons learned from agent sessions. Read before making changes.
See `lessons/` for full incident details.

Pitfalls marked **[GUARDED]** are mechanically enforced by hooks.
The rest require human/agent discipline.

---

## 0. SHORT TITLE — brief description [GUARDED]

**Severity: CRITICAL | HIGH | MEDIUM | LOW**

Description of what can go wrong and why it matters.

**Rules (ABSOLUTE — no exceptions):**
- Rule 1
- Rule 2

**Guard:** Name of the hook/script that enforces this (e.g., `migration-guard.sh`)

**Incident YYYY-MM-DD:** Brief narrative of when this happened and what was done.

---

## 1. Another pitfall [UNGUARDED]

Description.

**Rules:**
- Rule 1

**Guard:** None yet. Relies on agent discipline.
```

### Injection via sessionStart Hook

Create a `sessionStart` hook that reads the pitfalls file and injects it via `additionalContext`:

**hooks.json:**
```json
{
  "hooks": {
    "sessionStart": [
      {
        "type": "command",
        "bash": "bash .github/hooks/scripts/inject-memory.sh"
      }
    ]
  }
}
```

**inject-memory.sh:**
```bash
#!/usr/bin/env bash
set -euo pipefail

PITFALLS=".agents/memory/known-pitfalls.md"

if [[ -f "$PITFALLS" ]]; then
  CONTENT=$(cat "$PITFALLS")
  jq -cn --arg ctx "$CONTENT" '{additionalContext: $ctx}'
else
  jq -cn '{additionalContext: ""}'
fi
```

> **⚠️ Always output valid JSON.** Writing plain text to stdout in `sessionStart` causes `write EPIPE` (see `known-pitfalls.md` in this plugin for details).

## Lessons Learned Directory

`.agents/memory/lessons/` contains individual incident files for detailed post-mortems. The pitfalls file references these for full context.

### Lesson Template

```markdown
# Lesson: <short descriptive title>

**Date:** YYYY-MM-DD
**Workspace:** <affected directory/module>
**What happened:** <factual description of the incident>
**Root cause:** <why the mistake occurred — missing skill, wrong assumption, etc.>
**Correct approach:**
  1. Step one
  2. Step two
  3. Step three
**Added guard:** <hook/script name, or "None yet. Relies on agent discipline.">
```

### Naming Convention

Use kebab-case slugs that describe the incident:
- `http-call-in-cli-instead-of-sdk.md`
- `migration-missing-from-embedded-dir.md`
- `tailwind-breaks-dark-mode.md`

## Feature Requirements

`doc/requirements/features/<feature>.md` provides acceptance criteria that agents must read before implementing a feature.

### File Organization — Keep Entropy Low

**Do not create a new file for every requirement.** A proliferation of tiny files adds navigation overhead and makes the requirements directory harder to reason about.

Rules:
- **Group by domain/functionality**, not by individual requirement. A file should cover a coherent area (e.g., `auth.md`, `data-export.md`, `cli-ux.md`).
- **Add to an existing file** when the new requirement belongs to an already-covered domain. Only create a new file when no existing file is a logical home.
- **One file per feature cluster**, not one file per acceptance criterion.
- If a requirement touches multiple domains, place it in the file that owns the primary concern and cross-reference if needed.

Before creating a new file, scan `doc/requirements/features/` and ask: *does this belong in an existing file?*

### Requirements Template

```markdown
# Feature: <feature name>

## Context

<Why this feature exists and what problem it solves>

## Acceptance Criteria

- [ ] AC-001: <criterion>
- [ ] AC-002: <criterion>
- [ ] AC-003: <criterion>

## Constraints

- <constraint 1>
- <constraint 2>

## Non-Goals

- <what this feature explicitly does NOT cover>
```

### Workflow Integration

Reference requirements in `AGENTS.md` to enforce the read-before-implement pattern:

```markdown
## Mandatory Workflow

1. Read `.agents/memory/known-pitfalls.md`
2. Read `doc/requirements/features/<feature>.md` for acceptance criteria
3. Write failing tests first (TDD)
4. Implement
5. `make qa`
```

## Promoting Pitfalls from Lessons

When a lesson reveals a pattern that should be enforced:

1. Add a numbered entry to `known-pitfalls.md` with rules and guard status
2. If a hook can enforce the rule, write the hook and mark the pitfall `[GUARDED]`
3. If no hook exists yet, mark it `[UNGUARDED]` and track the guard as a TODO

## Guard Lifecycle

```
Incident → Lesson file → Pitfall entry [UNGUARDED] → Hook written → Pitfall updated to [GUARDED]
```

The goal is to move all high-severity pitfalls to `[GUARDED]` status over time, reducing reliance on agent discipline.
