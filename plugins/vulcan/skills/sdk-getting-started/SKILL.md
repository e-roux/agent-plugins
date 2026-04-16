---
name: sdk-getting-started
description: >
  Getting started with the Copilot SDK (@github/copilot-sdk) in TypeScript — installation, sessions,
  streaming, custom tools, slash commands, UI elicitation, and telemetry. Use when the user wants
  to build a standalone app with the SDK, send messages programmatically, define custom tools,
  stream responses, connect to a headless CLI server, or set up OpenTelemetry — even if they just
  say "use the copilot SDK" or "build an AI-powered app with copilot".
---

# Copilot SDK — Getting Started (TypeScript)

## Prerequisites

- **GitHub Copilot CLI** installed and authenticated
- **Node.js** 18+

Verify: `copilot --version`

## Installation

```bash
mkdir my-app && cd my-app
npm init -y --init-type module
npm install @github/copilot-sdk tsx
```

> **CJS compatibility:** The SDK ships both ESM and CJS builds, so it works in
> CommonJS projects (`require("@github/copilot-sdk")`) without extra config.

## Sending a Message

```typescript
import { CopilotClient } from "@github/copilot-sdk";

const client = new CopilotClient();
const session = await client.createSession({ model: "gpt-4.1" });

const response = await session.sendAndWait({ prompt: "What is 2 + 2?" });
console.log(response?.data.content);

await client.stop();
process.exit(0);
```

Run: `npx tsx index.ts`

## Streaming Responses

```typescript
import { CopilotClient } from "@github/copilot-sdk";

const client = new CopilotClient();
const session = await client.createSession({
    model: "gpt-4.1",
    streaming: true,
});

session.on("assistant.message_delta", (event) => {
    process.stdout.write(event.data.deltaContent);
});
session.on("session.idle", () => {
    console.log();
});

await session.sendAndWait({ prompt: "Tell me a short joke" });

await client.stop();
process.exit(0);
```

### Event Subscription

```typescript
// All events
const unsubscribe = session.on((event) => console.log("Event:", event.type));

// Specific event type (data is narrowed automatically)
const unsub = session.on("session.idle", (event) => console.log("Idle"));

// Unsubscribe later
unsubscribe();
```

## Custom Tools

Define tools that Copilot can invoke during conversations:

```typescript
import { CopilotClient, defineTool } from "@github/copilot-sdk";

const getWeather = defineTool("get_weather", {
    description: "Get the current weather for a city",
    parameters: {
        type: "object",
        properties: {
            city: { type: "string", description: "The city name" },
        },
        required: ["city"],
    },
    skipPermission: true, // bypass confirmation for low-risk tools
    handler: async (args: { city: string }) => {
        const { city } = args;
        const temp = Math.floor(Math.random() * 30) + 50;
        return { city, temperature: `${temp}°F`, condition: "sunny" };
    },
});

const client = new CopilotClient();
const session = await client.createSession({
    model: "gpt-4.1",
    streaming: true,
    tools: [getWeather],
});
```

### skipPermission

By default every tool invocation triggers a permission prompt. Set
`skipPermission: true` on the tool definition to bypass the prompt for
low-risk, read-only operations:

```typescript
const listFiles = defineTool("list_files", {
    description: "List files in a directory",
    parameters: {
        type: "object",
        properties: { dir: { type: "string" } },
        required: ["dir"],
    },
    skipPermission: true,
    handler: async ({ dir }: { dir: string }) => {
        const fs = await import("fs/promises");
        return await fs.readdir(dir);
    },
});
```

### How Tools Work

1. Copilot analyzes the user's prompt and decides to call your tool
2. The SDK runs your handler with the parsed arguments
3. The result is sent back to Copilot
4. Copilot incorporates the result into its response

## System Message (Simple)

Replace the entire system prompt with a static string:

```typescript
const session = await client.createSession({
    systemMessage: {
        content: "You are a helpful assistant. Always be concise.",
    },
});
```

## System Message (Customization)

Use `mode: "customize"` to surgically edit individual sections of the default
Copilot system prompt while keeping the rest intact. Ten configurable sections:
`identity`, `tone`, `tool_efficiency`, `environment_context`,
`code_change_rules`, `guidelines`, `safety`, `tool_instructions`,
`custom_instructions`, `last_instructions`.

Each section supports four static actions (`replace`, `remove`, `append`,
`prepend`) and a `transform` callback:

```typescript
import { CopilotClient, approveAll } from "@github/copilot-sdk";

const client = new CopilotClient();
const session = await client.createSession({
    onPermissionRequest: approveAll,
    systemMessage: {
        mode: "customize",
        sections: {
            // transform callback — receives the current section text
            identity: {
                action: (current) =>
                    current.replace("GitHub Copilot", "Acme Assistant"),
            },
            // static replace
            tone: {
                action: "replace",
                content: "Be concise and professional.",
            },
            // static remove
            code_change_rules: { action: "remove" },
            // static append
            guidelines: {
                action: "append",
                content: "\n- Always prefer TypeScript over JavaScript.",
            },
        },
    },
});
```

## Blob Attachments

Send images or binary content directly without writing to disk:

```typescript
import { readFileSync } from "fs";

const base64Str = readFileSync("diagram.png").toString("base64");

const response = await session.sendAndWait({
    prompt: "What's in this image?",
    attachments: [{ type: "blob", data: base64Str, mimeType: "image/png" }],
});
console.log(response?.data.content);
```

## Slash Commands & UI Elicitation (v0.2.1+)

```typescript
import { CopilotClient, approveAll } from "@github/copilot-sdk";

const client = new CopilotClient();
const session = await client.createSession({
    onPermissionRequest: approveAll,
    commands: [
        {
            name: "summarize",
            description: "Summarize the conversation",
            handler: async () => "Summarize the conversation in bullet points.",
        },
    ],
    onElicitationRequest: async (context) => {
        if (context.type === "confirm") return { action: "confirm" };
    },
});

const confirmed = await session.ui.confirm({ message: "Proceed?" });
const format = await session.ui.select({
    message: "Output format?",
    options: ["bullet list", "single paragraph"],
});

console.log({ confirmed, format });
```

> **Node v0.2.1+ breaking change:** `onElicitationRequest` now receives a single
> `ElicitationContext` argument rather than `(request, invocation)`.

## Session Metadata Lookup (v0.2.1+)

```typescript
const meta = await client.getSessionMetadata("user-123-task-456");

if (meta) {
    console.log(meta);
}
```

`getSessionMetadata()` returns `undefined` when the session does not exist, so it is cheaper than
listing every saved session when you only need one.

## Automatic Config Discovery (v0.2.2)

Let the runtime discover MCP servers and skill directories from the working directory:

```typescript
const session = await client.createSession({
  enableConfigDiscovery: true,
});
```

When enabled, the runtime scans for `.mcp.json` and skill directories in the working directory.
Discovered settings are merged with any explicitly provided values — explicit values take
precedence on name collision. Useful for zero-config SDK apps that should respect the project's
existing MCP/skill setup.

## Pre-select Custom Agent

Start a session with a custom agent already active:

```typescript
import { CopilotClient, approveAll } from "@github/copilot-sdk";

const client = new CopilotClient();
const session = await client.createSession({
    customAgents: [
        { name: "researcher", prompt: "You are a research assistant." },
    ],
    agent: "researcher",
    onPermissionRequest: approveAll,
});

const response = await session.sendAndWait({
    prompt: "Summarize the latest trends in AI",
});
console.log(response?.data.content);

await client.stop();
process.exit(0);
```

## Interactive Assistant Pattern

```typescript
import { CopilotClient, defineTool } from "@github/copilot-sdk";
import * as readline from "readline";

const myTool = defineTool("my_tool", { /* ... */ });

const client = new CopilotClient();
const session = await client.createSession({
    model: "gpt-4.1",
    streaming: true,
    tools: [myTool],
});

session.on("assistant.message_delta", (event) => {
    process.stdout.write(event.data.deltaContent);
});

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

const prompt = () => {
    rl.question("You: ", async (input) => {
        if (input.toLowerCase() === "exit") {
            await client.stop();
            rl.close();
            return;
        }
        process.stdout.write("Assistant: ");
        await session.sendAndWait({ prompt: input });
        console.log("\n");
        prompt();
    });
};

prompt();
```

## External CLI Server

Run the CLI separately and connect the SDK to it:

```bash
copilot --headless --port 4321
```

```typescript
import { CopilotClient, approveAll } from "@github/copilot-sdk";

const client = new CopilotClient({ cliUrl: "localhost:4321" });
const session = await client.createSession({ onPermissionRequest: approveAll });
```

When `cliUrl` is provided, the SDK does not spawn or manage a CLI process.

## Telemetry (OpenTelemetry)

```typescript
const client = new CopilotClient({
    telemetry: {
        otlpEndpoint: "http://localhost:4318",
        sourceName: "my-app",
    },
});
```

Optional peer dependency: `@opentelemetry/api`

### TelemetryConfig Options

| Option          | Description                              |
|-----------------|------------------------------------------|
| `otlpEndpoint`  | OTLP HTTP endpoint URL                   |
| `filePath`      | File path for JSON-lines trace output    |
| `exporterType`  | `"otlp-http"` or `"file"`               |
| `sourceName`    | Instrumentation scope name               |
| `captureContent`| Whether to capture message content       |

### File Export

```typescript
const client = new CopilotClient({
    telemetry: {
        filePath: "./traces.jsonl",
        exporterType: "file",
    },
});
```

Trace context is propagated automatically (SDK ↔ CLI) via W3C Trace Context headers.
