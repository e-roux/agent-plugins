---
name: sdk-mcp-servers
description: >
  Integrate MCP servers into Copilot SDK sessions in TypeScript — local/stdio and HTTP servers,
  per-agent MCP, combining with skills. Use when the user wants to connect external tools via
  MCP to an SDK app, add a database or filesystem MCP server, scope MCP to a specific agent,
  or combine MCP with skills — even if they just say "add MCP to my app" or "connect a
  postgres server".
---

# Copilot SDK — MCP Servers (TypeScript)

The SDK integrates with MCP servers to extend Copilot with external tools. For MCP server types and config options, see `resources/shared/mcp-server-types.md`.

## SDK Configuration

```typescript
import { CopilotClient } from "@github/copilot-sdk";

const client = new CopilotClient();
const session = await client.createSession({
    model: "gpt-4.1",
    mcpServers: {
        "my-local-server": {
            type: "local",
            command: "node",
            args: ["./mcp-server.js"],
            env: { DEBUG: "true" },
            cwd: "./servers",
            tools: ["*"],
            timeout: 30000,
        },
        "github": {
            type: "http",
            url: "https://api.githubcopilot.com/mcp/",
            headers: { "Authorization": "Bearer ${TOKEN}" },
            tools: ["*"],
        },
    },
});
```

## Quick Start: Filesystem MCP Server

```typescript
import { CopilotClient } from "@github/copilot-sdk";

const client = new CopilotClient();
const session = await client.createSession({
    mcpServers: {
        filesystem: {
            type: "local",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"],
            tools: ["*"],
        },
    },
});

const result = await session.sendAndWait({
    prompt: "List the files in the allowed directory",
});
console.log(result?.data?.content);

await session.disconnect();
await client.stop();
```

## MCP in CLI Plugins vs SDK

### In a CLI Plugin

Define servers in `.mcp.json` and reference from `plugin.json`. For details, see `resources/shared/mcp-config-locations.md`.

### In the SDK (programmatic)

Pass `mcpServers` directly in the session config as shown above.

## Runtime MCP Management (RPC)

SDK v0.2.0 adds low-level RPC methods to control MCP servers programmatically at runtime:

```typescript
// Session-scoped: enable/disable/reload without persisting changes
const servers = await session.rpc.mcp.list();
await session.rpc.mcp.enable("postgres");
await session.rpc.mcp.disable("experimental-server");
await session.rpc.mcp.reload();
```

## Persistent MCP Configuration (mcp.config.* RPC)

The `mcp.config.*` namespace manages **stored** MCP server configuration that survives session restarts — equivalent to editing `~/.copilot/mcp-config.json` programmatically:

```typescript
// List stored MCP configs
const configs = await session.rpc.mcp.config.list();

// Add a new persistent MCP server
await session.rpc.mcp.config.add("my-postgres", {
    command: "npx",
    args: ["-y", "@modelcontextprotocol/server-postgres"],
    env: { DATABASE_URL: "postgresql://localhost/mydb" },
});

// Update an existing config
await session.rpc.mcp.config.update("my-postgres", {
    env: { DATABASE_URL: "postgresql://prod-host/mydb" },
});

// Remove a stored config
await session.rpc.mcp.config.remove("my-postgres");
```

| Method               | Effect                               |
|----------------------|--------------------------------------|
| `mcp.config.list`    | Read stored server configurations    |
| `mcp.config.add`     | Add a new persistent server          |
| `mcp.config.update`  | Patch fields on an existing config   |
| `mcp.config.remove`  | Delete a stored server config        |

> **Tip:** Use `mcp.config.add` + `mcp.reload()` together — add the config persistently, then reload to activate it in the current session.

## MCP OAuth Authentication (/mcp auth)

MCP servers that require OAuth can be authenticated via the `/mcp auth` slash command in interactive sessions. This opens the re-authentication UI with account switching support:

```
/mcp auth <server-name>
```

For **headless and CI environments**, the CLI uses the device code flow (RFC 8628) as a fallback when browser-based OAuth is unavailable — the user authenticates on another device using a short code.

Since CLI v1.0.19, `/mcp enable` and `/mcp disable` also persist across sessions. And from v1.0.21, the dedicated `copilot mcp` command provides top-level MCP server management outside of interactive sessions. In v1.0.25, you can install MCP servers from the registry with guided configuration, and MCP remote server connections automatically retry on transient network failures.

## ACP MCP Server Provision (v1.0.25+)

ACP clients can now provide MCP servers (stdio, HTTP, SSE) when starting or loading sessions. This enables IDE-hosted MCP servers to be forwarded into the CLI runtime, so tools defined in VS Code or other ACP clients are available to the agent without separate CLI-side configuration.

## Combining MCP with Custom Agents

Each custom agent can have its own MCP servers. Use the `agent` field on `createSession` to pre-select an agent so its MCP servers are active from the start:

```typescript
const session = await client.createSession({
    customAgents: [
        {
            name: "db-analyst",
            description: "Database expert",
            prompt: "You analyze database schemas.",
            mcpServers: {
                database: {
                    command: "npx",
                    args: ["-y", "@modelcontextprotocol/server-postgres", "postgresql://localhost/mydb"],
                },
            },
        },
    ],
    agent: "db-analyst",  // Start with this agent active
    onPermissionRequest: async () => ({ kind: "approved" }),
});
```

## Combining MCP with Skills

```typescript
const session = await client.createSession({
    skillDirectories: ["./skills/database"],
    mcpServers: {
        postgres: {
            type: "local",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-postgres"],
            tools: ["*"],
        },
    },
    onPermissionRequest: async () => ({ kind: "approved" }),
});
```
