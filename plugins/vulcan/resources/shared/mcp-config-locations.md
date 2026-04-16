# MCP Configuration Locations & Precedence

## Config File Locations

MCP servers can be defined in multiple locations. Listed by precedence (lowest to highest):

| Location                                | Scope        | Portability   |
|-----------------------------------------|--------------|---------------|
| `~/.copilot/mcp-config.json`            | User global  | GitHub        |
| `.mcp.json`                             | Project      | **Portable**  |
| `.github/mcp.json`                      | Project      | GitHub        |
| Plugin MCP configs (`.mcp.json`)        | Plugin       | GitHub        |
| `--additional-mcp-config` flag          | CLI flag     | GitHub        |

MCP servers use **last-wins** precedence: later sources override earlier ones with the same server name.

> **⚠️ Breaking change (v1.0.22):** `.vscode/mcp.json` and `.devcontainer/devcontainer.json` are no longer read as MCP config sources. The CLI now only reads `.mcp.json`. A migration hint appears when `.vscode/mcp.json` is detected without `.mcp.json`. Move your server definitions to `.mcp.json` at the project root.

## Project-Local: .mcp.json (Recommended)

For project-level MCP, `.mcp.json` at the project root is the recommended portable location. It is recognized by VS Code, copilot-cli, and other MCP-aware tools.

```json
{
  "servers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      }
    },
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "DATABASE_URL": "${DATABASE_URL}"
      }
    }
  }
}
```

## Plugin-Level: .mcp.json

For CLI plugins, define MCP servers in `.mcp.json` at the plugin root and reference it from `plugin.json`:

```json
{
  "servers": {
    "filesystem": {
      "type": "local",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"],
      "tools": ["*"]
    }
  }
}
```

```json
{ "mcpServers": ".mcp.json" }
```

## Per-Agent MCP

MCP servers can be scoped to a specific agent via the `mcp-servers` YAML property in `.agent.md` files. See the agent-md-format reference.

## CLI MCP Management (v1.0.21+)

The `copilot mcp` command provides a dedicated CLI interface for managing MCP servers:

```bash
copilot mcp                    # Interactive MCP server management
```

In interactive sessions, `/mcp enable` and `/mcp disable` now persist across sessions (v1.0.19+), so servers you disable stay disabled when you resume or start a new session.

## MCP Registry Installation (v1.0.25+)

You can install MCP servers from the registry with guided configuration directly in the CLI. The install flow walks you through server-specific settings (API keys, database URLs, etc.) and persists the configuration automatically. MCP remote server connections also automatically retry on transient network failures (v1.0.25).
