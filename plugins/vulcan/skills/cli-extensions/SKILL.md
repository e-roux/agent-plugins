---
name: cli-extensions
description: >
  GitHub Copilot CLI extensions — project-local `.mjs` files that use the SDK extension API
  to register custom tools, intercept tool calls via hooks, listen to session events, and inject
  context. Use when the user wants to build an extension, add custom tools to their project,
  intercept agent behavior programmatically, auto-retry errors, redact secrets from tool output,
  or bridge the CLI to external systems — even if they just say "add an extension" or "intercept
  tool calls with code".
---

# Copilot CLI Extensions

## What Are Extensions?

Extensions are **project-local JavaScript modules** (`.mjs` files) that attach to a running Copilot CLI session. They use the SDK's `joinSession()` API to:

- Register **custom tools** the agent can call
- Intercept **tool calls** via lifecycle hooks (pre/post)
- **Inject context** into every prompt or at session start
- **Block dangerous operations** with `permissionDecision: "deny"`
- **Listen to session events** in real-time
- **Send programmatic prompts** via `session.send()`

Extensions are the **programmatic counterpart** to file-based hooks. While hooks are shell scripts that receive JSON on stdin and return JSON on stdout, extensions are full Node.js programs with access to the SDK's streaming API, event system, and tool registration.

## Extensions vs Plugins vs Hooks

| Aspect | Extensions | Plugins | File-Based Hooks |
|--------|-----------|---------|-----------------|
| **Location** | `.github/extensions/<name>/extension.mjs` | Distributed via `plugin.json` | `.github/hooks/*.json` |
| **Language** | JavaScript/TypeScript (`.mjs`) | Any (agents/skills are Markdown) | Any (shell scripts) |
| **Scope** | Project-local | Installable, cross-project | Project-local |
| **API** | Full SDK (`joinSession()`, events, tools) | Declarative (agents, skills, hooks) | stdin/stdout JSON |
| **Hot-reload** | `extensions_reload` or `/clear` | Reinstall | Automatic per invocation |
| **Custom tools** | ✅ Yes | Via MCP servers | ❌ No |
| **Event streaming** | ✅ `session.on(event)` | ❌ No | ❌ No |
| **Programmatic prompts** | ✅ `session.send()` | ❌ No | ❌ No |
| **Distribution** | Copy the file | Marketplace / `copilot plugin install` | Copy the file |

**When to use which:**
- **Extensions** — when you need custom tools, event listeners, programmatic control, or complex logic beyond what shell hooks can do
- **Plugins** — when you want distributable, versioned packages with agents, skills, and MCP servers
- **File-based hooks** — when you need simple policy enforcement (allow/deny) without full SDK access

## Setup

Create a file at `.github/extensions/<name>/extension.mjs`:

```javascript
import { approveAll } from "@github/copilot-sdk";
import { joinSession } from "@github/copilot-sdk/extension";

const session = await joinSession({
  onPermissionRequest: approveAll,
  hooks: {
    onSessionStart: async () => ({
      additionalContext: "Extension loaded. Custom rules apply.",
    }),
  },
  tools: [],
});
```

> **No `npm install` needed.** The `@github/copilot-sdk` package is auto-resolved by the CLI runtime. Extensions run as forked child processes with JSON-RPC communication.

After creating or editing an extension, activate it with `extensions_reload` in your session or `/clear`.

## Extension Lifecycle Hooks

Extensions receive the same hook events as file-based hooks, but with richer return values:

### `onSessionStart`

Fires when the session begins. Use to inject initial context.

```javascript
onSessionStart: async () => ({
  additionalContext: "Project rules: 2-space indent, no console.log in production.",
}),
```

### `onUserPromptSubmitted`

Fires when the user sends a prompt. Use for keyword detection or per-prompt context injection.

```javascript
onUserPromptSubmitted: async (input) => {
  if (/\bsecurity audit\b/i.test(input.prompt)) {
    return {
      additionalContext: "[workflow] Running security audit workflow.",
    };
  }
},
```

### `onPreToolUse`

Fires before a tool executes. Use to allow/deny, modify arguments, or inject context.

```javascript
onPreToolUse: async (input) => {
  if (input.toolName === "powershell") {
    const cmd = String(input.toolArgs?.command || "");
    if (/rm\s+-rf\s+\//i.test(cmd)) {
      return {
        permissionDecision: "deny",
        permissionDecisionReason: "Blocked: recursive delete from root.",
      };
    }
  }
},
```

### `onPostToolUse`

Fires after a tool succeeds. Use to track changes, inject follow-up context, or auto-open files.

```javascript
onPostToolUse: async (input) => {
  if (input.toolName === "edit" || input.toolName === "create") {
    const filePath = String(input.toolArgs?.path || "");
    return {
      additionalContext: `[tracker] File modified: ${filePath}`,
    };
  }
},
```

### `onPostToolUseFailure`

Fires after a tool fails. Separate from `onPostToolUse`.

### `onErrorOccurred`

Fires on errors. Use for retry logic.

```javascript
onErrorOccurred: async (input) => {
  if (input.recoverable && input.errorContext === "model_call") {
    return { errorHandling: "retry", retryCount: 3 };
  }
  if (input.recoverable && input.errorContext === "tool_execution") {
    return { errorHandling: "retry", retryCount: 2 };
  }
  return { errorHandling: "skip", userNotification: `Skipped: ${input.error}` };
},
```

## Hook Return Value API

All extension hooks can return an object with these fields:

| Field | Type | Description |
|-------|------|-------------|
| `additionalContext` | `string` | Injected into the agent's context for the current turn |
| `permissionDecision` | `"allow" \| "deny"` | Allow or deny the tool call (`onPreToolUse` only) |
| `permissionDecisionReason` | `string` | Explanation shown to the agent when denied |
| `modifiedArgs` | `object` | Rewrite tool arguments before execution (`onPreToolUse`, v1.0.24+) |
| `updatedInput` | `object` | Alternative to modifiedArgs for full input replacement (`onPreToolUse`, v1.0.24+) |
| `modifiedResult` | `{ textResultForLlm, resultType }` | Replace what the LLM sees from tool output (`onPostToolUse`) |
| `errorHandling` | `"retry" \| "skip" \| "abort"` | How to handle recoverable errors (`onErrorOccurred`) |
| `retryCount` | `number` | Max retries for the error (`onErrorOccurred`) |
| `userNotification` | `string` | Message displayed to the user (`onErrorOccurred`) |

## Custom Tools

Extensions can register tools the agent can call:

```javascript
const session = await joinSession({
  onPermissionRequest: approveAll,
  tools: [
    {
      name: "check_ci_status",
      description: "Check GitHub Actions workflow status",
      skipPermission: true,
      parameters: {
        type: "object",
        properties: {
          workflow: { type: "string", description: "Workflow filename (e.g., ci.yml)" },
        },
        required: ["workflow"],
      },
      handler: async (args) => {
        const { execFile } = await import("node:child_process");
        return new Promise((resolve) => {
          execFile("gh", [
            "run", "list", "--workflow", args.workflow,
            "--limit", "3", "--json", "status,conclusion,headBranch,createdAt",
          ], { timeout: 15000 }, (err, stdout) => {
            if (err) resolve(`Error: ${err.message}`);
            else resolve(stdout.trim() || "No runs found");
          });
        });
      },
    },
  ],
  hooks: {},
});
```

> Use `skipPermission: true` for read-only tools to bypass permission prompts.

## Event Listeners

Extensions can listen to real-time session events:

```javascript
session.on("tool.execution_start", (event) => {
  console.log(`Tool starting: ${event.data.toolName}`);
});

session.on("assistant.message", (event) => {
  console.log(`Agent says: ${event.data.content}`);
});

session.on("session.idle", async () => {
  // Agent finished — run post-turn checks
});

session.on("session.shutdown", (event) => {
  // Clean up resources
});
```

The `session.idle` event is especially powerful — it fires when the agent finishes a turn, letting you run automated checks (tests, lints) and send the agent back to work if they fail.

## Programmatic Prompts

Extensions can inject prompts into the session:

```javascript
session.send({
  prompt: "Tests failed. Fix the failures:\n```\n" + output + "\n```",
});

session.send({
  prompt: "Review this file.",
  attachments: [{ type: "file", path: "/path/to/file.ts" }],
});
```

> **Infinite loop warning:** If `onUserPromptSubmitted` calls `session.send()`, it can retrigger itself. Use `setTimeout(() => session.send(...), 0)` to break the cycle.

## Session Logging

```javascript
await session.log("Extension loaded", { level: "info" });
await session.log("Check running...", { ephemeral: true });
await session.log("Warning: rate limit approaching", { level: "warning" });
```

## Extension Patterns

### Self-Healing Loop (REPL Pattern)

Run tests after each agent turn; send failures back for fixing:

```javascript
session.on("session.idle", async () => {
  const result = await runCommand("npm", ["test"], process.cwd());
  if (!result.success) {
    await session.send({
      prompt: `Tests failed. Fix:\n\`\`\`\n${result.output.slice(-2000)}\n\`\`\``,
    });
  }
});
```

### Result Redaction

Strip secrets from tool output before the LLM sees them:

```javascript
onPostToolUse: async (input) => {
  const text = String(input.toolResult);
  const redacted = text.replace(/ghp_[a-zA-Z0-9]{36}/g, "[REDACTED]");
  if (redacted !== text) {
    return {
      modifiedResult: { textResultForLlm: redacted, resultType: "success" },
      additionalContext: "Some values were redacted for security.",
    };
  }
},
```

### Architecture Enforcement

Block imports that cross layer boundaries:

```javascript
onPostToolUse: async (input) => {
  if (input.toolName !== "edit" && input.toolName !== "create") return;
  const filePath = String(input.toolArgs?.path || "");
  const content = String(input.toolArgs?.new_str || input.toolArgs?.file_text || "");
  const imports = content.match(/import.*from\s+['"]([^'"]+)['"]/g) || [];
  // Check against boundary rules, return additionalContext with violations
},
```

### External Bridge (Telegram, Slack, etc.)

Bridge messages between an external chat platform and the CLI:

```javascript
// Poll external API → session.send() for incoming messages
// session.on("assistant.message") → post to external API for responses
```

## Management

| Command | Description |
|---------|-------------|
| `extensions_reload` | Reload all extensions without restarting session |
| `/clear` | Start new session (also reloads extensions) |
| `/extensions` | View, enable, and disable extensions |

## File Structure

```
.github/extensions/
├── security-shield/
│   └── extension.mjs       # Blocks dangerous commands, detects secrets
├── test-enforcer/
│   └── extension.mjs       # Blocks commits without test changes
├── lint-on-edit/
│   └── extension.mjs       # Auto-lints after every file edit
└── ci-monitor/
    └── extension.mjs       # Watches CI and feeds failures back to agent
```
