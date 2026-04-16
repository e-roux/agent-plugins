# .agent.md File Reference

Agent files use Markdown with YAML frontmatter. The filename (minus `.agent.md`) is the agent ID used for deduplication.

## Frontmatter Properties

| Property                    | Type           | Required | Description                                              |
|-----------------------------|----------------|----------|----------------------------------------------------------|
| `description`               | string         | yes      | Purpose and capabilities — drives auto-selection         |
| `name`                      | string         |          | Display name                                             |
| `tools`                     | list / string  |          | Tool allow-list. Omit or `["*"]` for all tools           |
| `model`                     | string         |          | Override the session model                               |
| `disable-model-invocation`  | boolean        |          | Prevent auto-selection (must be invoked manually)        |
| `user-invocable`            | boolean        |          | `false` = only accessible programmatically               |
| `mcp-servers`               | object         |          | Per-agent MCP server config (YAML)                       |
| `metadata`                  | object         |          | Arbitrary key-value annotations                          |

The Markdown body below the frontmatter defines the agent's behavior (max 30,000 characters).

## Tool Aliases

| Alias     | Maps to                        | Purpose                    |
|-----------|--------------------------------|----------------------------|
| `execute` | `bash`, `powershell`, `shell`  | Run shell commands         |
| `read`    | `view`, `Read`, `NotebookRead` | Read file contents         |
| `edit`    | `Edit`, `Write`, `MultiEdit`   | Modify files               |
| `search`  | `Grep`, `Glob`                 | Search files and content   |
| `agent`   | `custom-agent`, `Task`         | Invoke another agent       |
| `web`     | `WebSearch`, `WebFetch`        | Fetch URLs / web search    |
| `todo`    | `TodoWrite`                    | Create/manage task lists   |

## Examples

### Read-Only Agent

```markdown
---
description: Focuses on test coverage and quality without modifying production code
tools: ["read", "search", "edit", "execute"]
---

You are a testing specialist. Your responsibilities:

- Analyze existing tests and identify coverage gaps
- Write unit, integration, and e2e tests following best practices
- Ensure tests are isolated, deterministic, and well-documented
- Focus only on test files — avoid modifying production code unless asked
```

### Agent with Per-Agent MCP Server

```markdown
---
description: Analyzes database schemas and queries
tools: ["read", "search", "custom-mcp/query"]
mcp-servers:
  custom-mcp:
    type: local
    command: npx
    args: ["-y", "@modelcontextprotocol/server-postgres"]
    tools: ["*"]
    env:
      DATABASE_URL: ${{ secrets.DATABASE_URL }}
---

You are a database analyst. Use the PostgreSQL MCP server to inspect
schemas, analyze queries, and suggest optimizations.
```

Agent files are placed in `.github/agents/` for project-local agents (GitHub-specific — no portable alternative exists for agent discovery). See `resources/shared/loading-precedence.md` for the full loading order.

### Implementation Planner (Limited Tools)

```markdown
---
description: Creates detailed implementation plans and technical specifications
tools: ["read", "search", "edit"]
---

You are a technical planning specialist. Create comprehensive implementation
plans with clear steps, dependencies, and acceptance criteria.
```

## MCP in Agent Frontmatter

The `mcp-servers` YAML property scopes MCP servers to a specific agent. Secrets use `${{ secrets.NAME }}` or `${NAME}` syntax. The `stdio` type is mapped to `local` for compatibility.

## Selecting an Agent

```
/agent test-specialist
```

Or let the runtime auto-select based on the prompt and agent `description`.
