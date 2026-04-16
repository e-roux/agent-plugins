---
name: sdk-advanced
description: >
  Advanced Copilot SDK features in TypeScript — message steering and queueing, session persistence
  and resumption, infinite sessions, session metadata, image input, sessionFs, and skills
  integration. Use when the user wants to redirect an agent mid-turn, queue follow-up tasks, save
  and resume sessions, send images, or load skills into SDK sessions — even if they just say
  "resume a session" or "send multiple tasks in sequence".
---

# Copilot SDK — Advanced Features (TypeScript)

## Steering & Queueing

Two patterns for sending messages while the agent is busy:

| Mode          | Behavior                              | Use case                                |
|---------------|---------------------------------------|-----------------------------------------|
| `"immediate"` | Injected into the **current** turn    | Course-correct: "use a different approach" |
| `"enqueue"`   | Processed **after** current turn ends | Follow-up: "also fix the tests"         |

### Steering (Immediate)

```typescript
const session = await client.createSession({
    model: "gpt-4.1",
    onPermissionRequest: async () => ({ kind: "approved" }),
});

await session.send({ prompt: "Refactor the auth module to use sessions" });

await session.send({
    prompt: "Actually, use JWT tokens instead of sessions",
    mode: "immediate",
});
```

### Queueing (Enqueue)

```typescript
await session.send({ prompt: "Set up the project structure" });

await session.send({ prompt: "Add unit tests for auth", mode: "enqueue" });
await session.send({ prompt: "Update the README", mode: "enqueue" });
```

### When to Use Which

| Scenario                              | Pattern       |
|---------------------------------------|---------------|
| Agent is going the wrong direction    | Steering      |
| Additional context for current task   | Steering      |
| You want to chain multiple tasks      | Queueing      |
| Batch unrelated requests              | Queueing      |

---

## System Prompt Customization

Use `systemMessage` with `mode: "customize"` to modify the default system prompt without
replacing it entirely. Ten configurable sections:

| Section                | Purpose                                      |
|------------------------|----------------------------------------------|
| `identity`             | Who the assistant is                         |
| `tone`                 | Communication style                          |
| `tool_efficiency`      | Tool-use strategy                            |
| `environment_context`  | Runtime environment details                  |
| `code_change_rules`    | Rules for making code changes                |
| `guidelines`           | General behavioral guidelines                |
| `safety`               | Safety and compliance rules                  |
| `tool_instructions`    | Per-tool usage instructions                  |
| `custom_instructions`  | User/project custom instructions             |
| `last_instructions`    | Final instructions (highest priority)        |

### Section Actions

| Action      | Type       | Description                                       |
|-------------|------------|---------------------------------------------------|
| `"replace"` | string     | Replace the section with `content`                |
| `"remove"`  | string     | Remove the section entirely                       |
| `"append"`  | string     | Append `content` after the existing section       |
| `"prepend"` | string     | Prepend `content` before the existing section     |
| `transform` | callback   | `(current: string) => string` — arbitrary rewrite |

### Example

```typescript
const session = await client.createSession({
  onPermissionRequest: approveAll,
  systemMessage: {
    mode: "customize",
    sections: {
      identity: {
        action: (current) => current.replace("GitHub Copilot", "Acme Assistant"),
      },
      tone: { action: "replace", content: "Be concise and professional." },
      code_change_rules: { action: "remove" },
      custom_instructions: { action: "append", content: "\n\nAlways use TypeScript." },
    },
  },
});
```

The `transform` callback receives the current section text and returns the modified text.
String actions (`"replace"`, `"append"`, `"prepend"`) use the `content` field.
Sections not listed in `sections` are left unchanged.

---

## Session Persistence

### Creating a Resumable Session

```typescript
const session = await client.createSession({
    sessionId: "user-123-task-456",
    model: "gpt-4.1",
});

await session.sendAndWait({ prompt: "Analyze my codebase" });
```

### Resuming a Session

```typescript
const session = await client.resumeSession("user-123-task-456");
await session.sendAndWait({ prompt: "What did we discuss earlier?" });
```

### Resume with Changed Config

```typescript
const session = await client.resumeSession("user-123-task-456", {
    model: "claude-sonnet-4",
    reasoningEffort: "high",
});
```

### Session ID Best Practices

| Pattern                            | Example                    | Use Case          |
|------------------------------------|----------------------------|-------------------|
| `user-{userId}-{taskId}`          | `user-alice-pr-review-42`  | Multi-user apps   |
| `tenant-{tenantId}-{workflow}`    | `tenant-acme-onboarding`   | Multi-tenant SaaS |
| `{userId}-{taskId}-{timestamp}`   | `alice-deploy-1706932800`  | Time-based cleanup|

### What Gets Persisted

| Data                  | Persisted? | Notes                              |
|-----------------------|------------|-------------------------------------|
| Conversation history  | Yes        | Full message thread                 |
| Tool call results     | Yes        | Cached for context                  |
| Agent planning state  | Yes        | `plan.md` file                      |
| Session artifacts     | Yes        | In `files/` directory               |
| Provider/API keys     | No         | Must re-provide on resume           |
| In-memory tool state  | No         | Design tools to be stateless        |

### Managing Sessions

```typescript
const sessions = await client.listSessions();
await client.deleteSession("user-123-task-456");
await session.disconnect();
```

### Fetching Metadata Without Listing Everything (v0.2.1+)

```typescript
const meta = await client.getSessionMetadata("user-123-task-456");

if (!meta) {
    console.log("Session not found");
} else {
    console.log(meta);
}
```

`getSessionMetadata()` returns `undefined` when the session does not exist, so you can check one
session cheaply without enumerating every saved session first.

### Infinite Sessions

```typescript
const session = await client.createSession({
    sessionId: "long-workflow-123",
    infiniteSessions: {
        enabled: true,
        backgroundCompactionThreshold: 0.80,
        bufferExhaustionThreshold: 0.95,
    },
});
```

### Custom Session Storage (`sessionFs`, all SDKs v0.2.2+)

All four SDKs can now redirect per-session storage (event logs and large output files) through a
custom `sessionFs` adapter. Use this when the default on-disk session directory is not durable
enough, or when you need to back session artifacts with object storage or another external system.

```typescript
const client = new CopilotClient({
  sessionFs: { initialCwd: "/", sessionStatePath: "/s", conventions: "posix" },
});

const session = await client.createSession({
  createSessionFsHandler: () => ({
    readFile: async () => "...",
    writeFile: async () => { /* ... */ },
  }),
});
```

> **History:** `sessionFs` was Node-only in v0.2.1. Since v0.2.2, it is available in .NET, Go,
> and Python as well. See the [copilot-sdk-server-sample](https://github.com/github/copilot-sdk-server-sample)
> for a full multi-user hosted example.

---

## Model Switching with Reasoning Effort

Change the model mid-session with an optional `reasoningEffort` parameter:

```typescript
await session.setModel("claude-sonnet-4", { reasoningEffort: "high" });
```

Valid `reasoningEffort` values: `"low"`, `"medium"`, `"high"`. Omit to use the model default.

### Overriding Model Capabilities (v0.2.2)

Override individual model capabilities without replacing the full capabilities object:

```typescript
const session = await client.createSession({
  modelCapabilities: { supports: { vision: false } },
});

await session.setModel("claude-sonnet-4.5", {
  modelCapabilities: { supports: { vision: true } },
});
```

This is useful for BYOK/custom-provider scenarios where the default capability detection may be wrong.

This also works when resuming sessions:

```typescript
const session = await client.resumeSession("user-123-task-456", {
    model: "claude-sonnet-4",
    reasoningEffort: "high",
});
```

---

## Skills in the SDK

Load skills from directories. For the `SKILL.md` format, see `resources/shared/skill-md-format.md`.

```typescript
const session = await client.createSession({
    model: "gpt-4.1",
    skillDirectories: ["./skills/code-review", "./skills/documentation"],
    disabledSkills: ["experimental-feature"],
    onPermissionRequest: async () => ({ kind: "approved" }),
});
```

### Combining Skills with Agents

```typescript
const session = await client.createSession({
    skillDirectories: ["./skills/security"],
    customAgents: [{
        name: "security-auditor",
        description: "Security-focused code reviewer",
        prompt: "Focus on OWASP Top 10 vulnerabilities",
    }],
    onPermissionRequest: async () => ({ kind: "approved" }),
});
```

---

## Image Input

### File Attachment

```typescript
await session.send({
    prompt: "Describe what you see in this image",
    attachments: [{
        type: "file",
        path: "/absolute/path/to/screenshot.png",
    }],
});
```

### Blob Attachment (in-memory data)

The recommended approach for sending in-memory data — screenshots, API responses, generated
images, or any binary content that does not exist on disk:

```typescript
await session.send({
    prompt: "Describe this image",
    attachments: [{
        type: "blob",
        data: base64ImageData,
        mimeType: "image/png",
        displayName: "screenshot.png",
    }],
});
```

Supported formats: JPG, PNG, GIF. The model must have `capabilities.supports.vision = true`.

---

## Custom Model Listing (BYOK)

Applications using bring-your-own-key providers can supply a custom model listing callback:

```typescript
const client = createClient({
    onListModels: async () => [
        { id: "my-fine-tuned-model", name: "My Fine-Tuned Model" },
        { id: "gpt-4.1", name: "GPT-4.1" },
    ],
});
```

This enables `setModel` to work with custom or self-hosted models not in the default catalog.

---

## RPC Methods

Low-level RPC methods for direct control of skills, MCP servers, extensions, plugins,
UI, shell, and logging. These are emerging APIs — signatures may evolve.

### Skills

```typescript
await session.rpc.skills.list();
await session.rpc.skills.enable("my-skill");
await session.rpc.skills.disable("my-skill");
await session.rpc.skills.reload();
```

### MCP Servers

```typescript
// Runtime session management (in-memory — resets when session ends)
await session.rpc.mcp.list();
await session.rpc.mcp.enable("postgres-server");
await session.rpc.mcp.disable("experimental-server");
await session.rpc.mcp.reload();
```

```typescript
// Persistent config management (survives session restart)
await session.rpc.mcp.config.list();
await session.rpc.mcp.config.add("my-server", { command: "npx", args: ["-y", "@modelcontextprotocol/server-postgres"] });
await session.rpc.mcp.config.update("my-server", { env: { DATABASE_URL: "..." } });
await session.rpc.mcp.config.remove("my-server");
```

> **`mcp.*` vs `mcp.config.*`:** `mcp.*` methods control the live session state (enable/disable/reload at runtime). `mcp.config.*` methods manage the **stored** MCP configuration that persists across sessions — equivalent to editing `~/.copilot/mcp-config.json` programmatically.

### Extensions

```typescript
await session.rpc.extensions.list();
await session.rpc.extensions.enable("my-extension");
await session.rpc.extensions.disable("my-extension");
await session.rpc.extensions.reload();
```

### Plugins

```typescript
await session.rpc.plugins.list();
```

### UI — Structured User Input (Elicitation)

> **Prefer the high-level UI APIs when possible:** On v0.2.1+, use `commands` plus
> `session.ui.confirm()` / `session.ui.select()` for common interaction patterns. Drop to
> `session.rpc.ui.elicitation()` when you need a custom multi-field form or lower-level control.

```typescript
await session.rpc.ui.elicitation({
    title: "Configure deployment",
    fields: [
        { id: "env", label: "Environment", type: "text" },
        { id: "confirm", label: "Confirm?", type: "boolean" },
    ],
});
```

### Shell

```typescript
await session.rpc.shell.exec("npm test");
await session.rpc.shell.kill(pid);
```

### Logging

```typescript
session.log("Checkpoint reached", "info", /* ephemeral */ false);
```

---

> **Removed in v0.2.0 — `autoRestart`**
>
> The `autoRestart` option has been deprecated and has no effect. Remove it from
> `createSession` / `resumeSession` options. Sessions that disconnect must be explicitly
> re-created or resumed.

---

## Streaming Events

For the full event catalog (40+ event types), see `streaming-events-catalog.md` in this skill's directory.

Key subscription pattern:

```typescript
session.on("assistant.message_delta", (event) => {
    process.stdout.write(event.data.deltaContent);
});

session.on("session.idle", () => {
    console.log();
});
```
