---
name: sdk-custom-agents
description: >
  Copilot SDK custom agents and sub-agent orchestration in TypeScript. Use when the user wants
  to define custom agents in the SDK, scope tools per agent, orchestrate sub-agents, attach
  MCP servers to specific agents, or handle sub-agent lifecycle events — even if they just say
  "add agents to my SDK app" or "delegate tasks to sub-agents".
---

# Copilot SDK — Custom Agents & Sub-Agent Orchestration (TypeScript)

Custom agents are lightweight agent definitions attached to a session. Each has its own system prompt, tool restrictions, and optional MCP servers. The runtime auto-delegates to matching agents as sub-agents.

## Defining Custom Agents

```typescript
import { CopilotClient } from "@github/copilot-sdk";

const client = new CopilotClient();
const session = await client.createSession({
    model: "gpt-4.1",
    customAgents: [
        {
            name: "researcher",
            displayName: "Research Agent",
            description: "Explores codebases and answers questions using read-only tools",
            tools: ["grep", "glob", "view"],
            prompt: "You are a research assistant. Analyze code and answer questions. Do not modify any files.",
        },
        {
            name: "editor",
            displayName: "Editor Agent",
            description: "Makes targeted code changes",
            tools: ["view", "edit", "bash"],
            prompt: "You are a code editor. Make minimal, surgical changes to files as requested.",
        },
    ],
    onPermissionRequest: async () => ({ kind: "approved" }),
});
```

## Configuration Reference

| Property      | Type             | Required | Description                                              |
|---------------|------------------|----------|----------------------------------------------------------|
| `name`        | `string`         | yes      | Unique identifier for the agent                          |
| `displayName` | `string`         |          | Human-readable name shown in events                      |
| `description` | `string`         |          | What the agent does — helps the runtime select it        |
| `tools`       | `string[] | null`|          | Tools the agent can use. `null`/omitted = all tools      |
| `prompt`      | `string`         | yes      | System prompt for the agent                              |
| `mcpServers`  | `object`         |          | MCP server configurations specific to this agent         |
| `infer`       | `boolean`        |          | Whether runtime can auto-select this agent (default: true)|

## Pre-selecting an Agent (v0.2.0+)

Specify which custom agent should be active when a session starts, eliminating the need for a separate `session.rpc.agent.select()` call:

```typescript
const session = await client.createSession({
    customAgents: [
        { name: "researcher", prompt: "You are a research assistant." },
        { name: "editor", prompt: "You are a code editor." },
    ],
    agent: "researcher", // Active from the first prompt
    onPermissionRequest: async () => ({ kind: "approved" }),
});
```

## How Sub-Agent Delegation Works

1. **Intent matching** — Runtime analyzes prompt against each agent's `name` and `description`
2. **Agent selection** — If matched and `infer !== false`, runtime selects the agent
3. **Isolated execution** — Sub-agent runs with its own prompt and restricted tool set
4. **Event streaming** — Lifecycle events stream back to the parent session
5. **Result integration** — Sub-agent output is incorporated into the parent response

### Controlling Inference

```typescript
{
    name: "dangerous-cleanup",
    description: "Deletes unused files and dead code",
    tools: ["bash", "edit", "view"],
    prompt: "You clean up codebases by removing dead code.",
    infer: false, // Only invoked when user explicitly asks
}
```

## Scoping Tools per Agent

```typescript
customAgents: [
    {
        name: "reader",
        description: "Read-only exploration of the codebase",
        tools: ["grep", "glob", "view"],  // No write access
        prompt: "You explore and analyze code. Never modify files.",
    },
    {
        name: "writer",
        description: "Makes code changes",
        tools: ["view", "edit", "bash"],   // Write access
        prompt: "You make precise code changes as instructed.",
    },
    {
        name: "unrestricted",
        description: "Full access agent for complex tasks",
        tools: null,                        // All tools
        prompt: "You handle complex multi-step tasks.",
    },
]
```

## Attaching MCP Servers to Agents

```typescript
customAgents: [
    {
        name: "db-analyst",
        description: "Analyzes database schemas and queries",
        prompt: "You are a database expert.",
        mcpServers: {
            database: {
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-postgres", "postgresql://localhost/mydb"],
            },
        },
    },
]
```

## Sub-Agent Event Types

| Event                  | Emitted when                        | Key Data                              |
|------------------------|-------------------------------------|---------------------------------------|
| `subagent.selected`    | Runtime selects an agent            | `agentName`, `agentDisplayName`, `tools` |
| `subagent.started`     | Sub-agent begins execution          | `toolCallId`, `agentName`, `agentDisplayName`, `agentDescription` |
| `subagent.completed`   | Sub-agent finishes successfully     | `toolCallId`, `agentName`, `agentDisplayName` |
| `subagent.failed`      | Sub-agent encounters an error       | `toolCallId`, `agentName`, `error`    |
| `subagent.deselected`  | Runtime switches away               | —                                     |

### Listening to Events

```typescript
session.on((event) => {
    switch (event.type) {
        case "subagent.started":
            console.log(`Sub-agent started: ${event.data.agentDisplayName}`);
            break;
        case "subagent.completed":
            console.log(`Sub-agent completed: ${event.data.agentDisplayName}`);
            break;
        case "subagent.failed":
            console.log(`Sub-agent failed: ${event.data.agentDisplayName} — ${event.data.error}`);
            break;
        case "subagent.selected":
            console.log(`Agent selected: ${event.data.agentDisplayName}`);
            break;
        case "subagent.deselected":
            console.log("Agent deselected, returning to parent");
            break;
    }
});
```

## Building an Agent Tree UI

```typescript
interface AgentNode {
    toolCallId: string;
    name: string;
    displayName: string;
    status: "running" | "completed" | "failed";
    error?: string;
    startedAt: Date;
    completedAt?: Date;
}

const agentTree = new Map<string, AgentNode>();

session.on((event) => {
    if (event.type === "subagent.started") {
        agentTree.set(event.data.toolCallId, {
            toolCallId: event.data.toolCallId,
            name: event.data.agentName,
            displayName: event.data.agentDisplayName,
            status: "running",
            startedAt: new Date(event.timestamp),
        });
    }
    if (event.type === "subagent.completed") {
        const node = agentTree.get(event.data.toolCallId);
        if (node) {
            node.status = "completed";
            node.completedAt = new Date(event.timestamp);
        }
    }
    if (event.type === "subagent.failed") {
        const node = agentTree.get(event.data.toolCallId);
        if (node) {
            node.status = "failed";
            node.error = event.data.error;
            node.completedAt = new Date(event.timestamp);
        }
    }
});
```

## Runtime Agent Management (RPC)

SDK v0.2.0 adds low-level RPC methods for runtime agent control:

```typescript
// Select an agent programmatically during a session
await session.rpc.agent.select("editor");

// List available agents
const agents = await session.rpc.agent.list();
```

These are emerging APIs without friendly wrappers yet.

## Best Practices

- **Pair a researcher with an editor** — read-only exploration + write-capable implementation
- **Keep descriptions specific** — vague descriptions lead to poor delegation
- **Handle failures** — always listen for `subagent.failed` events
- **Use `infer: false`** for destructive agents — require explicit invocation
- **Pre-select with `agent` field** — use `agent: "name"` in `createSession` instead of a separate RPC call
- **Use `skipPermission: true`** on safe tools to avoid redundant permission prompts in agent scopes
