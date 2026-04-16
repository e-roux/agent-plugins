---
name: project-local-customization
description: >
  Customize Copilot CLI for a specific repository — project agents, skills, hooks,
  custom instructions, and MCP servers. Use when the user wants to configure copilot
  for their project, add a custom agent or skill to a repo, set up hooks, write
  instructions, or configure MCP — even if they just say "customize copilot for
  this repo" or "add an agent to my project".
---

# Project-Local Customization

Customize AI agent behavior for a specific repository without building a plugin or SDK application. All configuration lives inside the project tree and is version-controlled alongside your code.

This guide organizes options by portability: **portable** conventions work across copilot-cli, Claude Code, Cursor, and other tools. **GitHub-specific** conventions require the GitHub/Copilot ecosystem.

## Customization Overview

### Portable (cross-tool)

| Feature              | Location                                          | Purpose                                              |
|----------------------|---------------------------------------------------|------------------------------------------------------|
| Agent instructions   | `AGENTS.md` (repo root or cwd)                    | Project-wide guidance for any AI agent               |
| Skills               | `.claude/skills/NAME/SKILL.md`                    | Task-specific instructions — discovered by both Copilot CLI and Claude Code |
| MCP servers          | `.mcp.json` (project root)                        | Project MCP servers (standard MCP config)        |

### GitHub ecosystem

| Feature              | Location                                          | Purpose                                              |
|----------------------|---------------------------------------------------|------------------------------------------------------|
| Custom agents        | `.github/agents/*.agent.md`                       | Specialized agents scoped to the project             |
| Skills (alternative) | `.github/skills/NAME/SKILL.md`                    | Same SKILL.md format but GitHub-specific path        |
| Custom instructions  | `.github/copilot-instructions.md`                 | Repo-wide guidance added to every prompt             |
| Path instructions    | `.github/instructions/*.instructions.md`          | File-pattern-scoped instructions                     |
| Hooks                | `.github/hooks/hooks.json`                        | Shell scripts at session lifecycle points            |
| MCP (alternative)    | `.github/mcp.json`                                | Same as `.mcp.json` but GitHub-specific path         |
| Settings             | `.claude/settings.json`, `.claude/settings.local.json` | Additional repo config sources (v1.0.12+)      |
| Cloud agent env      | `.github/workflows/copilot-setup-steps.yml`       | Preinstall tools/deps, choose runners, set env for GitHub-hosted Copilot cloud agent |

### Claude Code ecosystem

| Feature              | Location                                          | Purpose                                              |
|----------------------|---------------------------------------------------|------------------------------------------------------|
| Custom agents        | `.claude/agents/*.md`                             | Specialized agents scoped to the project             |
| Instructions bridge  | `CLAUDE.md` with `@AGENTS.md` import              | Imports shared `AGENTS.md` into Claude Code          |
| Path-scoped rules    | `.claude/rules/*.md`                              | File-pattern-scoped instructions (Claude Code only)  |
| Hooks                | `.claude/settings.json` hooks section             | Shell/prompt hooks at lifecycle points               |

## Agent Instructions (Portable)

`AGENTS.md` at the repository root (or working directory) provides project-wide guidance to any AI agent — copilot-cli, Claude Code, Cursor, and others all read it.

```markdown
# AGENTS.md

This is a TypeScript monorepo using pnpm workspaces.

- Use strict TypeScript (`strict: true`)
- Prefer functional patterns over classes
- All public APIs must have JSDoc comments
- Use Vitest for testing
```

Also recognized: `CLAUDE.md`, `GEMINI.md`. All instruction files are additive — they do not override each other.

If you need **only** copilot-cli support, `.github/copilot-instructions.md` provides the same role with additional features like path-scoped instructions (see GitHub-specific section below).

## Skills (Portable)

Place skills under `.claude/skills/NAME/SKILL.md` for cross-tool compatibility. This path is explicitly discovered by both Copilot CLI (priority 3) and Claude Code (native).

```
.claude/
└── skills/
    ├── deploy/
    │   ├── SKILL.md
    │   └── deploy.sh
    └── code-review/
        └── SKILL.md
```

Alternative locations: `.github/skills/` (GitHub-only), `.agents/skills/` (Copilot CLI "Portable" label, but not explicitly documented in Claude Code). All follow the same SKILL.md format. See `resources/shared/skill-md-format.md` for the full format reference and CLI commands.

Before creating a project skill, check `/skills list`. Since CLI v1.0.17, the CLI also ships
built-in skills, so repository skills should add project-specific behavior rather than duplicate a
default guide.

## MCP Servers (Portable)

`.mcp.json` at the project root is the recommended location for project MCP. It is recognized by VS Code, copilot-cli, and other MCP-aware tools.

> **⚠️ Breaking change (v1.0.22):** `.vscode/mcp.json` and `.devcontainer/devcontainer.json` are no longer read as MCP config sources. Migrate to `.mcp.json` at the project root.

For the `.mcp.json` format, all config locations, and precedence rules, see `resources/shared/mcp-config-locations.md`. For server type options (local/HTTP), see `resources/shared/mcp-server-types.md`.

Per-agent MCP can also be defined in `.agent.md` frontmatter (see `resources/shared/agent-md-format.md`).

## Custom Agents (DRY — `.claude/agents/`)

Both tools now discover `.claude/agents/` for project-level agents:

- **Copilot CLI**: discovers `.claude/agents/*.agent.md` (in addition to `.github/agents/`)
- **Claude Code**: discovers `.claude/agents/*.md` natively

Use the `.agent.md` extension — required by Copilot CLI, accepted by Claude Code (matches `*.md` glob).

```
.claude/
└── agents/
    ├── reviewer.agent.md     # Discovered by both tools
    └── db-analyst.agent.md
```

For the full frontmatter reference, tool aliases, and examples, see `resources/shared/agent-md-format.md`.

## GitHub-Specific Instructions

### Repository-Wide

Create `.github/copilot-instructions.md` — appended to every prompt in this repository:

```markdown
This is a TypeScript monorepo using pnpm workspaces.

- Use strict TypeScript (`strict: true`)
- Prefer functional patterns over classes
```

### Path-Specific

Create `.github/instructions/NAME.instructions.md` with a `globs` frontmatter field:

```markdown
---
globs: ["src/api/**/*.ts"]
---

API route handlers must:
- Validate input with zod schemas
- Return proper HTTP status codes
- Include OpenAPI annotations
```

Path-scoped instructions are a GitHub-specific feature with no portable equivalent.

## Cloud Agent Environment (GitHub-Specific)

Use `.github/workflows/copilot-setup-steps.yml` to customize the GitHub-hosted Copilot cloud agent environment: preinstall dependencies, select larger or self-hosted runners, switch to Windows, or set environment variables before the agent starts.

Since CLI v1.0.17, this topic is also covered by the built-in `customizing-copilot-cloud-agents-environment` skill. Use that built-in skill when the request is about GitHub-hosted agent environments rather than local CLI/project customization.

## MCP Server Management (CLI v1.0.21+)

The `copilot mcp` command provides a dedicated interface for managing MCP servers from the CLI:

```bash
copilot mcp                    # Interactive MCP server management
```

This complements the existing `/mcp` slash commands in interactive sessions. Since v1.0.19, `/mcp enable` and `/mcp disable` also persist across sessions.

## Hooks (Tool-Specific)

Repository hooks run shell scripts at session lifecycle points. Each tool has its own hook configuration format:

- **Copilot CLI**: `.github/hooks/hooks.json` (camelCase events: `preToolUse`, `sessionStart`)
- **Claude Code**: `.claude/settings.json` hooks section (PascalCase events: `PreToolUse`, `SessionStart`)

For DRY projects, keep hook **scripts** in a shared `scripts/` directory and reference them from both configurations. See `resources/shared/dual-tool-setup.md` for the dual-wiring pattern.

For the hook points table and configuration format, see `resources/shared/hook-lifecycle.md`.

Recent CLI additions: `permissionRequest` (v1.0.16) lets scripts participate when the runtime is
about to ask for approval, `notification` (v1.0.18) fires asynchronously for shell completion,
permission prompts, elicitation dialogs, and agent completion, and hooks configured with PascalCase
event names now receive VS Code-compatible snake_case payloads with `hook_event_name`, `session_id`,
and ISO 8601 timestamps (v1.0.21).

`preToolUse` still handles the main policy decision before a tool runs. On v1.0.18+, returning
`{ "permissionDecision": "allow" }` from it suppresses the approval prompt altogether.

### Template Variables (v1.0.12+)

Hook configurations support template variables that are resolved at runtime:

| Variable              | Resolved to                                |
|-----------------------|--------------------------------------------|
| `{{project_dir}}`     | The project's root directory               |
| `{{plugin_data_dir}}` | The plugin's persistent data directory     |

Plugin hooks also receive corresponding environment variables: `CLAUDE_PROJECT_DIR` and `CLAUDE_PLUGIN_DATA`. Since v1.0.26, plugin hooks also receive `PLUGIN_ROOT`, `COPILOT_PLUGIN_ROOT`, and `CLAUDE_PLUGIN_ROOT` pointing to the plugin's installation directory.

### Directory Structure

```
.github/
└── hooks/
    ├── hooks.json
    ├── scripts/
    │   ├── audit-prompt.sh
    │   └── block-dangerous-commands.sh
    └── logs/               # Add to .gitignore
```

### Example hooks.json

```json
{
  "version": 1,
  "hooks": {
    "preToolUse": [
      { "type": "command", "bash": "bash .github/hooks/scripts/block-dangerous-commands.sh" }
    ],
    "userPromptSubmitted": [
      { "type": "command", "bash": "bash .github/hooks/scripts/audit-prompt.sh" }
    ]
  }
}
```

> **⚠️ Always use the array format.** The flat object syntax (`"preToolUse": { "bash": "..." }`) is silently ignored — hooks never fire. See `resources/shared/known-pitfalls.md` for details.

## Putting It All Together

### Portable-first project layout (DRY for Copilot CLI + Claude Code)

```
my-project/
├── AGENTS.md                                  # Project instructions (single source of truth)
├── CLAUDE.md                                  # Thin bridge: @AGENTS.md + Claude-specific overrides
├── .mcp.json                                  # MCP servers (fully shared)
├── .claude/
│   ├── settings.json                          # Shared settings + Claude Code hooks
│   ├── settings.local.json                    # Personal overrides (gitignored)
│   ├── rules/                                 # Claude Code path-scoped rules
│   │   └── api-style.md
│   ├── skills/                                # Skills (discovered by both tools)
│   │   ├── deploy/
│   │   │   ├── SKILL.md
│   │   │   └── deploy.sh
│   │   └── code-review/
│   │       └── SKILL.md
│   └── agents/                                # Claude Code agents
│       └── reviewer.md
├── .github/                                   # GitHub/Copilot CLI additions
│   ├── agents/
│   │   ├── reviewer.agent.md                  # Copilot CLI agents
│   │   └── db-analyst.agent.md
│   ├── hooks/
│   │   ├── hooks.json                         # Copilot CLI hooks
│   │   └── scripts/
│   │       └── audit-prompt.sh
│   ├── copilot-instructions.md                # Copilot-specific instructions (optional)
│   └── instructions/
│       └── api-routes.instructions.md         # Path-scoped (.github/ only)
├── scripts/                                   # Shared hook scripts
│   └── block-dangerous.sh
└── src/
    └── ...
```

For the full DRY strategy with configuration comparison tables, see `resources/shared/dual-tool-setup.md`.

### Precedence Recap

- **Agents & skills**: project-level always wins over plugins (first-found-wins)
- **MCP servers**: later sources override earlier ones (last-wins)
- **Instructions**: `AGENTS.md` + `.github/copilot-instructions.md` + path-specific are all additive
- **Hooks**: repository hooks run alongside any plugin hooks

For the full loading order, see `resources/shared/loading-precedence.md`. For the comprehensive DRY dual-tool setup guide, see `resources/shared/dual-tool-setup.md`.
