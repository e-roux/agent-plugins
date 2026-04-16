# agent-plugin-vulcan

A [GitHub Copilot CLI plugin](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference) that provides an expert agent for building Copilot CLI plugins and standalone SDK applications.

Vulcan complements the CLI's built-in skills with deeper guidance for plugin authoring, project-local customization, and SDK application design. On CLI v1.0.17+, it can also route cloud-agent environment questions to the built-in guidance for `.github/workflows/copilot-setup-steps.yml`.

## What is Vulcan?

Vulcan is a specialist agent that knows how to:

- **Customize copilot-cli for a project** — set up project-local agents, skills, hooks, instructions, and MCP servers using DRY conventions (`.claude/skills/`, `AGENTS.md` + `CLAUDE.md` bridge, `.mcp.json`) that work across both Copilot CLI and Claude Code
- **Build CLI extensions** — create project-local `.mjs` extensions using `joinSession()` for custom tools, hook interception, event-driven workflows, self-healing loops, and result redaction
- **Build Copilot CLI plugins** — scaffold `plugin.json`, write `.agent.md` agents, create `SKILL.md` skills, configure hooks, set up MCP/LSP servers, create marketplace manifests
- **Build standalone SDK applications** — create TypeScript apps using `@github/copilot-sdk` v0.2.2 with custom tools, slash commands, UI elicitation, session metadata lookup, session persistence, hooks, MCP integration, system prompt customization, blob attachments, `enableConfigDiscovery` for automatic MCP/skill loading, and cross-SDK `sessionFs` for custom session storage. CLI v1.0.22+ removes `.vscode/mcp.json` and `.devcontainer/devcontainer.json` as MCP config sources — only `.mcp.json` is read. CLI v1.0.27 adds `/ask` for quick questions, `copilot plugin marketplace update`, plugin hook `PLUGIN_ROOT` env vars, instruction file deduplication, and context compaction checkpoint fix.

## Plugin Structure

```
agent-plugin-vulcan/
├── .claude-plugin/
│   └── plugin.json                      # Plugin manifest (discovered by both Copilot CLI and Claude Code)
├── agents/
│   └── vulcan.agent.md                  # The Vulcan specialist agent
├── scripts/
│   └── version-check.sh                # Version bump check (used by hooks)
├── resources/
│   └── shared/                          # Shared reference material
│       ├── agent-md-format.md           # .agent.md frontmatter, tool aliases
│       ├── skill-md-format.md           # SKILL.md format, CLI commands
│       ├── mcp-server-types.md          # MCP server types & options
│       ├── mcp-config-locations.md      # MCP config locations & precedence
│       ├── loading-precedence.md        # Loading order for agents, skills, MCP
│       ├── hook-lifecycle.md            # Hook points, lifecycle, return value API
│       ├── skill-writing-guide.md       # Skill writing best practices
│       ├── dual-tool-setup.md           # DRY config for Copilot CLI + Claude Code
│       └── known-pitfalls.md            # Accumulated gotchas (agent memory)
└── skills/
    ├── project-local-customization/
    │   └── SKILL.md                     # Project agents, skills, hooks, MCP, instructions
    ├── project-memory/
    │   └── SKILL.md                     # Known pitfalls, lessons learned, requirements
    ├── cli-plugin-reference/
    │   └── SKILL.md                     # CLI plugin structure, manifest, commands
    ├── cli-extensions/
    │   └── SKILL.md                     # CLI extensions: joinSession, custom tools, events
    ├── sdk-getting-started/
    │   └── SKILL.md                     # SDK setup, sessions, streaming, tools
    ├── sdk-custom-agents/
    │   └── SKILL.md                     # Sub-agent orchestration, scoped tools
    ├── sdk-hooks/
    │   └── SKILL.md                     # Lifecycle hooks, permissions, auditing
    ├── sdk-mcp-servers/
    │   └── SKILL.md                     # MCP server integration (local & remote)
    └── sdk-advanced/
        ├── SKILL.md                     # Steering/queueing, persistence, images
        └── streaming-events-catalog.md  # Full SDK event type reference
```

## Installation

### Via marketplace (works in both Copilot CLI and Claude Code)

```bash
copilot plugin marketplace add e-roux/agent-plugins
copilot plugin install vulcan@e-roux-plugins
```

```bash
claude plugin marketplace add e-roux/agent-plugins
claude plugin install vulcan@e-roux-plugins
```

### Direct install (Copilot CLI only)

```bash
copilot plugin install e-roux/agent-plugin-vulcan
```

### Local clone

```bash
git clone https://github.com/e-roux/agent-plugin-vulcan.git
copilot plugin install ./agent-plugin-vulcan
claude --plugin-dir ./agent-plugin-vulcan
```

## Usage

Once installed, the Vulcan agent is available in any `copilot` session. You can select it explicitly:

```
/agent vulcan
```

Or let the runtime auto-select it when your prompt matches its expertise (e.g., "create a copilot plugin that...").

### Example Prompts

**Building a CLI plugin:**
```
Create a copilot-cli plugin called "code-quality" with an agent that reviews code
and a skill for linting configuration.
```

**Building an SDK application:**
```
Build a TypeScript CLI app using the Copilot SDK that has a custom weather tool
and streams responses to the terminal.
```

**Customizing copilot-cli for a project:**
```
Set up my repo with a testing agent, a deploy skill, repository hooks
for auditing, and a PostgreSQL MCP server.
```

**Learning about the ecosystem:**
```
Explain how MCP servers work in the Copilot SDK and show me how to connect
a PostgreSQL MCP server to a session.
```

## Skills Reference

| Skill                          | Loading      | Description                                                    |
|--------------------------------|-------------|----------------------------------------------------------------|
| `project-local-customization`  | Plugin-level | DRY-first project setup: `AGENTS.md` + `CLAUDE.md` bridge, `.claude/skills/`, `.mcp.json`, tool-specific agents/hooks, dual-tool configuration guide |
| `project-memory`               | Plugin-level | Persistent agent memory: known pitfalls, lessons learned, feature requirements, `sessionStart` injection |
| `cli-plugin-reference`         | Eager (Vulcan) | Plugin structure, plugin.json, marketplace, CLI commands, extensions vs plugins |
| `cli-extensions`               | Eager (Vulcan) | CLI extensions: `joinSession()`, custom tools, hooks, event listeners, self-healing loops |
| `sdk-getting-started`          | Eager (Vulcan) | SDK installation, sessions, streaming, custom tools, slash commands, UI elicitation, system prompt customization, telemetry |
| `sdk-custom-agents`            | Eager (Vulcan) | Custom agents, sub-agent orchestration, agent pre-selection, scoped tools, events   |
| `sdk-hooks`                    | Eager (Vulcan) | Programmatic lifecycle hooks, permissions, skipPermission, auditing, error handling |
| `sdk-mcp-servers`              | Eager (Vulcan) | MCP server integration, per-agent MCP, runtime MCP management (RPC), `copilot mcp` CLI command, combining with skills   |
| `sdk-advanced`                 | Eager (Vulcan) | System prompt customization, steering/queueing, session persistence, session metadata, sessionFs, blob attachments, RPC methods |

> **Loading modes:** *Plugin-level* skills appear in `/skills list` and are triggered by any agent based on description match. *Eager (Vulcan)* skills are pre-loaded into the Vulcan agent context at startup via the `skills` frontmatter field (CLI v1.0.22+), eliminating trigger-match latency. They remain in `skills/` for discoverability.

## Shared Resources

Shared reference material lives in `resources/shared/` and is referenced by multiple skills to avoid duplication:

| Resource                 | Content                                        |
|--------------------------|------------------------------------------------|
| `agent-md-format.md`    | `.agent.md` frontmatter properties, tool aliases, examples |
| `skill-md-format.md`    | `SKILL.md` format, frontmatter fields, CLI commands |
| `mcp-server-types.md`   | MCP server types (local/HTTP), options, popular servers |
| `mcp-config-locations.md`| Config file locations, precedence, `.mcp.json` format  |
| `loading-precedence.md` | Full loading order for agents, skills, MCP, extensions — with Copilot CLI and Claude Code discovery comparison |
| `hook-lifecycle.md`     | Hook points, lifecycle flow, **hook return value API**, file-based & SDK & extension hooks |
| `skill-writing-guide.md`| Progressive disclosure, description craft, iterative development |
| `known-pitfalls.md`    | Accumulated gotchas — MCP config (v1.0.22), hooks (v1.0.24, v1.0.26), skill instruction persistence (v1.0.25), SDK (v0.2.2), extension pitfalls, dual-tool discovery issues |
| `cli-flags-and-sessions.md` | CLI invocation modes, session management, remote access/control, slash commands (`/ask`, `/env`, `/fleet`, `/delegate`, `/pr`), `@` file mentions, background agents |
| `dual-tool-setup.md`   | DRY configuration guide for Copilot CLI + Claude Code: shared paths, separate-but-DRY patterns, recommended project layout |

## License

MIT
