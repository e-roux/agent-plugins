---
name: sdk-hooks
description: >
  Copilot SDK programmatic hooks for TypeScript — lifecycle callbacks for permissions, auditing,
  prompt enrichment, secret redaction, user-input handling, and error handling. Use when the user
  wants to control tool permissions, audit session activity, redact secrets from tool output,
  enrich prompts with context, or handle errors in SDK sessions — even if they just say
  "add permission checks" or "log what the agent does".
---

# Copilot SDK — Hooks (TypeScript)

Hooks let you plug custom logic into every stage of a Copilot session. For the hook lifecycle points table (shared with file-based hooks), see `resources/shared/hook-lifecycle.md`.

## Registering Hooks

```typescript
import { CopilotClient } from "@github/copilot-sdk";

const client = new CopilotClient();
const session = await client.createSession({
    hooks: {
        onSessionStart:        async (input, invocation) => { /* ... */ },
        onPreToolUse:          async (input, invocation) => { /* ... */ },
        onPostToolUse:         async (input, invocation) => { /* fires on SUCCESS only */ },
        onPostToolUseFailure:  async (input, invocation) => { /* fires on FAILURE only */ },
        onUserPromptSubmitted: async (input, invocation) => { /* ... */ },
        onAgentStop:           async (input, invocation) => { /* ... */ },
        onSubagentStop:        async (input, invocation) => { /* ... */ },
        onSessionEnd:          async (input, invocation) => { /* ... */ },
        onErrorOccurred:       async (input, invocation) => { /* ... */ },
    },
    onPermissionRequest: async () => ({ kind: "approved" }),
});
```

The `invocation` parameter contains the `sessionId` for correlating logs.

### Catch-All Event Handler (onEvent)

Register `onEvent` on the session config to receive **every** lifecycle event. Because it is set before the RPC is issued, early events like `session.start` are never dropped:

```typescript
const session = await client.createSession({
    onEvent: (event) => {
        console.log(`[${event.type}]`, event.data);
    },
    onPermissionRequest: async () => ({ kind: "approved" }),
});
```

Use `onEvent` for observability dashboards, structured logging, or replaying sessions — anywhere you need a single stream of all events without wiring individual hooks.

### User Input Handler (`onElicitationRequest`, v0.2.1+)

Structured UI requests are configured on the session itself rather than inside `hooks`:

```typescript
const session = await client.createSession({
    onElicitationRequest: async (context) => {
        if (context.type === "confirm") return { action: "confirm" };
        return null;
    },
    onPermissionRequest: async () => ({ kind: "approved" }),
});
```

> **Node v0.2.1+ breaking change:** `onElicitationRequest` now receives a single
> `ElicitationContext` argument instead of `(request, invocation)`.

## Permission Control (onPreToolUse)

### Allow-list safe tools

```typescript
const READ_ONLY_TOOLS = ["read_file", "glob", "grep", "view"];

hooks: {
    onPreToolUse: async (input) => {
        if (!READ_ONLY_TOOLS.includes(input.toolName)) {
            return {
                permissionDecision: "deny",
                permissionDecisionReason: `"${input.toolName}" was blocked.`,
            };
        }
        return { permissionDecision: "allow" };
    },
}
```

### Restrict file access

```typescript
const ALLOWED_DIRS = ["/home/user/projects", "/tmp"];

hooks: {
    onPreToolUse: async (input) => {
        if (["read_file", "write_file", "edit"].includes(input.toolName)) {
            const filePath = (input.toolArgs as { path: string }).path;
            const allowed = ALLOWED_DIRS.some((dir) => filePath.startsWith(dir));
            if (!allowed) {
                return {
                    permissionDecision: "deny",
                    permissionDecisionReason: `Access to "${filePath}" is outside allowed directories.`,
                };
            }
        }
        return { permissionDecision: "allow" };
    },
}
```

### Ask user before destructive operations

```typescript
hooks: {
    onPreToolUse: async (input) => {
        if (["delete_file", "shell", "bash"].includes(input.toolName)) {
            return { permissionDecision: "ask" };
        }
        return { permissionDecision: "allow" };
    },
}
```

### Observer / no-op permission handler ("no-result")

Permission handlers can return `"no-result"` to abstain from the decision. This lets extensions attach to sessions for monitoring without actively answering permission requests:

```typescript
hooks: {
    onPreToolUse: async (input) => {
        metrics.increment(`tool.invoked.${input.toolName}`);
        // Don't influence the permission outcome — let another handler decide.
        return { permissionDecision: "no-result" };
    },
}
```

> **Summary of permission outcomes:** `"allow"` | `"deny"` | `"ask"` | `"no-result"`

> **v1.0.18+:** Returning `"allow"` actively suppresses the runtime approval prompt. Return
> `"no-result"` or `null` if you only want to observe without taking the final decision.

## Tool-Level Permission Bypass (skipPermission)

For tools that are **always safe** (read-only queries, pure computations), you can bypass the confirmation prompt declaratively with `skipPermission: true` on the tool definition. This complements `onPreToolUse` hooks — use it when the tool is inherently safe regardless of context:

```typescript
import { defineTool } from "@github/copilot-sdk";

const readFile = defineTool("read_file", {
    description: "Read a file from disk",
    parameters: { type: "object", properties: { path: { type: "string" } }, required: ["path"] },
    skipPermission: true,  // Never prompts for permission
    handler: async (args: { path: string }) => {
        return await fs.promises.readFile(args.path, "utf-8");
    },
});
```

**When to use each approach:**

| Approach | Use when |
|---|---|
| `skipPermission: true` | Tool is unconditionally safe (no side effects, no secrets) |
| `onPreToolUse` hook | Decision depends on runtime context (args, user, environment) |
| Both | `skipPermission` handles the common case; hook adds conditional restrictions |

## Tool Failure Handling (onPostToolUseFailure)

`onPostToolUseFailure` fires when a tool call **errors**. `onPostToolUse` fires only on **success**. Handle both if you need complete coverage.

> **⚠️ Behavioral change:** Before this hook was added, `postToolUse` fired unconditionally. It now fires on success only. Audit hooks that relied on `postToolUse` to catch all outcomes must be updated to also register `onPostToolUseFailure`.

```typescript
hooks: {
    onPostToolUse: async (input, invocation) => {
        auditLog.push({
            event: "tool_success",
            toolName: input.toolName,
            toolArgs: input.toolArgs,
            result: input.toolResult,
        });
        return null;
    },
    onPostToolUseFailure: async (input, invocation) => {
        auditLog.push({
            event: "tool_failure",
            toolName: input.toolName,
            toolArgs: input.toolArgs,
            error: input.error,            // { message, name, stack }
        });
        return null;
    },
}
```

`input.toolResult` is a structured object. Preserve fields such as `resultType` and
`textResultForLlm` in your audit trail instead of flattening it to a string too early.

## Auditing

```typescript
const auditLog: AuditEntry[] = [];

hooks: {
    onSessionStart: async (input, invocation) => {
        auditLog.push({ timestamp: input.timestamp, sessionId: invocation.sessionId, event: "session_start" });
        return null;
    },
    onPreToolUse: async (input, invocation) => {
        auditLog.push({ timestamp: input.timestamp, sessionId: invocation.sessionId, event: "tool_call", toolName: input.toolName, toolArgs: input.toolArgs });
        return { permissionDecision: "allow" };
    },
    onPostToolUse: async (input, invocation) => {
        auditLog.push({ timestamp: input.timestamp, sessionId: invocation.sessionId, event: "tool_result", toolName: input.toolName, toolResult: input.toolResult });
        return null;
    },
    onSessionEnd: async (input, invocation) => {
        await fs.promises.writeFile(`audit-${invocation.sessionId}.json`, JSON.stringify(auditLog, null, 2));
        return null;
    },
}
```

## Secret Redaction (onPostToolUse)

```typescript
hooks: {
    onPostToolUse: async (input) => {
        const original = input.toolResult?.textResultForLlm;
        if (!original) return null;
        let redacted = original;
        for (const pattern of SECRET_PATTERNS) {
            redacted = redacted.replace(pattern, "[REDACTED]");
        }
        return redacted !== original ? { modifiedResult: redacted } : null;
    },
}
```

When structured tool results are available, redact the `textResultForLlm` field rather than
treating `toolResult` itself as a raw string.

## Prompt Enrichment

### Inject project metadata at session start

```typescript
hooks: {
    onSessionStart: async (input) => {
        const pkg = JSON.parse(await fs.promises.readFile("package.json", "utf-8"));
        return {
            additionalContext: [
                `Project: ${pkg.name} v${pkg.version}`,
                `Node: ${process.version}`,
                `CWD: ${input.cwd}`,
            ].join("\n"),
        };
    },
}
```

### Expand shorthand commands

```typescript
const SHORTCUTS: Record<string, string> = {
    "/fix":     "Find and fix all errors in the current file",
    "/test":    "Write comprehensive unit tests for this code",
    "/explain": "Explain this code in detail",
};

hooks: {
    onUserPromptSubmitted: async (input) => {
        for (const [shortcut, expansion] of Object.entries(SHORTCUTS)) {
            if (input.prompt.startsWith(shortcut)) {
                const rest = input.prompt.slice(shortcut.length).trim();
                return { modifiedPrompt: rest ? `${expansion}: ${rest}` : expansion };
            }
        }
        return null;
    },
}
```

## Error Handling (onErrorOccurred)

```typescript
hooks: {
    onErrorOccurred: async (input) => {
        if (input.errorContext === "model_call" && input.recoverable) {
            return { errorHandling: "retry", retryCount: 3, userNotification: "Retrying..." };
        }
        return null;
    },
}
```

## Best Practices

1. **Keep hooks fast** — they run inline; offload heavy work to background queues
2. **Return `null` when nothing changes** — avoids unnecessary allocation
3. **Be explicit with permission decisions** — `{ permissionDecision: "allow" }` is clearer than `null`
4. **Use `additionalContext` over `modifiedPrompt`** — preserves user intent
5. **Scope state by session ID** — key on `invocation.sessionId`, clean up in `onSessionEnd`
6. **Prefer `skipPermission: true` over hooks for always-safe tools** — it is declarative, self-documenting, and avoids an extra async round-trip through the hook chain
7. **Use `onEvent` for broad observability** — one handler captures all lifecycle events without wiring each hook individually
8. **Register both `onPostToolUse` and `onPostToolUseFailure` for complete audit coverage** — `onPostToolUse` fires on success only; failures are silently missed without the failure hook
