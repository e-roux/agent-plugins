# Hook Lifecycle

Hooks fire at well-defined points in the Copilot session lifecycle. The core lifecycle hooks apply to both file-based hooks (project-local, plugin, user-level) and SDK programmatic hooks; newer file-based additions such as `permissionRequest` and `notification` are called out explicitly below.

> **Portability note:** File-based hooks are GitHub/copilot-cli specific — there is no portable project-level hook mechanism. SDK programmatic hooks are tool-agnostic (they run wherever your TypeScript application runs).

> **Empirically verified through CLI v1.0.18** for the core synchronous hook lifecycle. `permissionRequest` (v1.0.16) and asynchronous `notification` hooks (v1.0.18) are newer release-note additions; public docs still lag their exact payload schema, so capture sample stdin before depending on field names. In v1.0.21, hooks configured with PascalCase event names receive VS Code-compatible snake_case payloads with `hook_event_name`, `session_id`, and ISO 8601 timestamps. In v1.0.22, `sessionStart` and `sessionEnd` fire once per session in interactive mode (not once per prompt). In v1.0.24, `preToolUse` hooks now respect `modifiedArgs`/`updatedInput` and `additionalContext` fields — hooks can modify tool arguments or inject additional context that the runtime will apply before executing the tool. In v1.0.25, skill instructions persist correctly across conversation turns and custom instruction files preserve special characters like `&` and `<placeholders>`. In v1.0.26, the `notification` hook for permission prompts only fires when a prompt is actually shown to the user (no longer fires for auto-approved actions), and plugin hooks receive three new env vars: `PLUGIN_ROOT`, `COPILOT_PLUGIN_ROOT`, and `CLAUDE_PLUGIN_ROOT` pointing to the plugin's installation directory.

## Hook Types

| Hook                    | When it fires                                   | Typical use cases                             |
|-------------------------|------------------------------------------------|-----------------------------------------------|
| `sessionStart`          | Session begins or resumes                      | Inject context (via additionalContext), load preferences |
| `userPromptSubmitted`   | User sends a prompt                            | Log input, validate, audit                    |
| `preToolUse`            | Before a tool executes                         | Allow/deny, enforce policy, audit             |
| `permissionRequest`     | When the runtime is about to surface a permission prompt (v1.0.16+) | Auto-approve/deny, bridge approval into custom UIs |
| `postToolUse`           | After a tool returns **successfully**          | Audit results, redact secrets, track stats    |
| `postToolUseFailure`    | After a tool call **fails** with an error      | Log errors, alert on failures, track error rates |
| `agentStop`             | Main agent finished responding to a prompt     | Access transcript, log turn completion        |
| `subagentStop`          | A subagent completes (returns to parent)       | Aggregate subagent results, audit delegation  |
| `sessionEnd`            | Session ends                                   | Clean up, persist logs, record metrics        |
| `errorOccurred`         | An error is raised                             | Custom logging, alerts                        |
| `notification`          | Asynchronous shell/permission/elicitation/agent-complete notification (v1.0.18+) | Desktop alerts, webhooks, passive telemetry   |

> **⚠️ `postToolUse` vs `postToolUseFailure` split:** `postToolUse` fires **only when the tool succeeds**. `postToolUseFailure` fires **only when the tool errors**. If you were previously using `postToolUse` to catch all outcomes, you must now also handle `postToolUseFailure` for error cases. This is a **breaking behavioral change** from earlier versions where `postToolUse` fired unconditionally.

> **Recent file-based additions:** `permissionRequest` is conditional and only fires when the runtime needs a permission decision. `notification` is asynchronous and is intended for passive alerts/telemetry rather than inline policy enforcement.

## Lifecycle Flow (Empirically Verified — `-p` mode, v1.0.11)

```
CLI receives -p prompt  →  userPromptSubmitted   ← fires FIRST (before sessionStart!)
Session initializes     →  sessionStart
Agent picks tool        →  preToolUse
Tool executes OK        →  postToolUse           ← only on success
Tool executes w/ error  →  postToolUseFailure    ← only on failure
  ↑ loops for each tool call
Agent finishes turn     →  agentStop             ← fires after all tools, before sessionEnd
Session ends            →  sessionEnd
Error anytime           →  errorOccurred
Subagent completes      →  subagentStop          ← only when subagents are used
```

> **Conditional/out-of-band hooks:** `permissionRequest` only appears when the runtime needs an approval decision. `notification` is asynchronous and may fire after shell completion, permission prompts, elicitation dialogs, or agent completion rather than inline with the blocking flow above.

> **⚠️ Ordering in `-p` mode:** `userPromptSubmitted` fires **before** `sessionStart`. This is
> the opposite of the documented order. Do not assume session context from `sessionStart` is
> available when `userPromptSubmitted` runs.

> **`agentStop` vs `sessionEnd`:** `agentStop` fires once per agent turn (when the model stops
> generating); `sessionEnd` fires once when the entire CLI session terminates.

## Input JSON Schema

All hooks receive a JSON object on stdin. Every hook input includes:

| Field       | Type   | Description                                 |
|-------------|--------|---------------------------------------------|
| `sessionId` | string | UUID identifying the session                |
| `timestamp` | number | Unix timestamp in milliseconds              |
| `cwd`       | string | Current working directory                   |

Additional per-hook fields:

| Hook                  | Extra fields                                                                          |
|-----------------------|---------------------------------------------------------------------------------------|
| `sessionStart`        | `source` ("new"\|"resume"\|"startup"), `initialPrompt`                               |
| `userPromptSubmitted` | `prompt`                                                                              |
| `preToolUse`          | `toolName`, `toolArgs` **(JSON string — must parse with `jq -r '.toolArgs\|fromjson'`)** |
| `postToolUse`         | `toolName`, `toolArgs` **(parsed object)**, `toolResult` (`{resultType, textResultForLlm}`) |
| `postToolUseFailure`  | `toolName`, `toolArgs` **(parsed object)**, `error` (`{message, name, stack}`)       |
| `agentStop`           | `transcriptPath` (path to events.jsonl), `stopReason` ("end_turn"\|…)               |
| `sessionEnd`          | `reason` ("complete"\|"error"\|"abort"\|"timeout"\|"user_exit")                      |
| `errorOccurred`       | `error` (`{message, name, stack}`)                                                    |

> **⚠️ `toolArgs` type inconsistency:** In `preToolUse` it is a **JSON string**; in `postToolUse`
> it is a **parsed object**. Parse accordingly.

> **Newer hook payloads:** `permissionRequest` (v1.0.16+) and `notification` (v1.0.18+) are newer than the empirically mapped table above. Inspect captured stdin in your target CLI build before hard-coding their exact field names.

## Hook Payload Normalization (v1.0.21+)

Hooks configured with PascalCase event names (e.g., `PreToolUse` instead of `preToolUse`) now receive VS Code-compatible snake_case payloads. The normalized fields include:

| Field               | Description                        |
|---------------------|------------------------------------|
| `hook_event_name`   | The hook event type in snake_case  |
| `session_id`        | Session UUID                       |
| Timestamps          | ISO 8601 format strings            |

This normalization ensures consistency between copilot-cli and VS Code extension hook consumers. If your hooks use PascalCase event names, expect the payload to use snake_case field names.

## Hook Configuration Format

The **only** supported format (flat object syntax does not work):

```json
{
  "version": 1,
  "hooks": {
    "sessionEnd": [
      {
        "type": "command",
        "bash": "bash scripts/version-check.sh",
        "timeoutSec": 15
      }
    ]
  }
}
```

Per hook entry fields: `type` (required, always `"command"`), `bash`, `powershell`, `cwd`, `env`, `timeoutSec` (default: 30).

### Template Variables (v1.0.12+)

Hook configurations support runtime-resolved template variables in `cwd`, `env`, and `bash` fields:

| Variable              | Resolved to                                     |
|-----------------------|-------------------------------------------------|
| `{{project_dir}}`     | The user's project root directory               |
| `{{plugin_data_dir}}` | Persistent data directory for this plugin       |

Plugin hooks also receive environment variables `CLAUDE_PROJECT_DIR` and `CLAUDE_PLUGIN_DATA`, accessible in hook scripts. Since v1.0.26, plugin hooks also receive `PLUGIN_ROOT`, `COPILOT_PLUGIN_ROOT`, and `CLAUDE_PLUGIN_ROOT` — all three point to the plugin's installation directory.

```json
{
  "hooks": {
    "sessionEnd": [
      {
        "type": "command",
        "bash": "bash scripts/check.sh",
        "cwd": "{{plugin_data_dir}}/..",
        "timeoutSec": 15
      }
    ]
  }
}
```

Multiple hooks of the same type run in declared order:

```json
"preToolUse": [
  { "type": "command", "bash": "bash .github/hooks/scripts/security.sh" },
  { "type": "command", "bash": "bash .github/hooks/scripts/audit.sh" }
]
```

## File-Based Hook Locations

| Location | Scope | How loaded | Portability |
|---|---|---|---|
| `.github/hooks/*.json` | Project | CWD discovery up to git root | GitHub |
| Plugin `hooks.json` (via `plugin.json` `hooks` field) | Plugin | Plugin manifest | GitHub |
| `~/.copilot/config.json` (hooks section) | User global | Always loaded | GitHub |
| `settings.json`, `settings.local.json` | Project | CWD | GitHub |

> **Monorepo support (v1.0.11+):** Hooks are discovered at every directory level from CWD
> up to the git root, enabling per-workspace hooks in monorepos.

> **Plugin hooks:** Must be declared in `plugin.json` via `"hooks": "path/to/hooks.json"`.
> The `.github/hooks/` directory is project-local only — it is **not** automatically loaded
> for plugin installs.

## Plugin Hook Environment Variables (v1.0.12+, expanded v1.0.26)

Plugin hooks (those declared in `plugin.json`) receive additional environment variables:

| Variable              | Value                                           |
|-----------------------|-------------------------------------------------|
| `CLAUDE_PROJECT_DIR`  | The user's project root directory               |
| `CLAUDE_PLUGIN_DATA`  | Persistent data directory for this plugin        |
| `PLUGIN_ROOT`         | The plugin's installation directory (v1.0.26+)  |
| `COPILOT_PLUGIN_ROOT` | Same as `PLUGIN_ROOT` (v1.0.26+)               |
| `CLAUDE_PLUGIN_ROOT`  | Same as `PLUGIN_ROOT` (v1.0.26+)               |

These are only set for **plugin** hooks — project-local hooks in `.github/hooks/` do not receive them. Use these to resolve paths in hook scripts without relying on `cwd`:

```bash
#!/usr/bin/env bash
# Available in plugin hooks since v1.0.12
cd "${CLAUDE_PROJECT_DIR:-$(pwd)}"
```

## `sessionStart` — additionalContext (v1.0.11+)

Since v1.0.11, the `sessionStart` hook can inject context into the agent's conversation by
writing a JSON object with `additionalContext` to **stdout**. Before v1.0.11 this was
silently ignored.

> **Hook stderr is NOT shown in the terminal** — the CLI captures it and routes it to
> `~/.copilot/logs/`. `additionalContext` via stdout is the only way to pass information
> from `sessionStart` into the session. Empirically verified v1.0.11.

## `preToolUse` — Output for Permission Control

The `preToolUse` hook can output JSON to allow/deny a tool:

```json
{ "permissionDecision": "deny", "permissionDecisionReason": "Dangerous command detected" }
```

| Decision  | Effect                                    |
|-----------|-------------------------------------------|
| `"allow"` | Tool executes immediately (skips the approval prompt) |
| `"deny"`  | Tool is blocked (with optional reason)    |
| `"ask"`   | Delegates decision to user at runtime     |

Omitting output leaves the runtime's normal permission flow in place.

> **v1.0.18+:** Returning `{ "permissionDecision": "allow" }` suppresses the interactive approval prompt and executes the tool immediately. Omit output if you only want passive logging without taking the decision yourself.

> **`permissionDecisionReason` IS shown in the session UI** — this is the only hook output

## `preToolUse` — Auto-Correction via `modifiedArgs` (v1.0.24+)

Instead of denying a tool call, `preToolUse` can **silently rewrite** the arguments and let the tool proceed with the corrected version. This transforms policy enforcement from "block and retry" into "detect and correct":

```json
{
  "modifiedArgs": { "command": "make test" },
  "additionalContext": "Redirected pytest → make test. Use make targets."
}
```

The `additionalContext` is critical — without it, the agent doesn't learn WHY the redirect happened and will repeat the violation. With it, the agent adapts within the session.

### Block vs Redirect Decision Matrix

| Violation | Pattern | Action |
|-----------|---------|--------|
| Clear mapping exists | `pytest` → `make test` | **Redirect** via `modifiedArgs` |
| Arguments matter | `ruff check --fix src/` → `make lint` | **Redirect** (make target handles flags) |
| Domain judgment needed | `size_class_counter: 8` → `16` | **Redirect** for simple values, **deny** for ambiguous ones |
| Dangerous/irreversible | `DROP TABLE`, secrets in code | **Deny** always |
| Complex rewrite needed | `python3 script.py arg1 arg2` | **Deny** (rewrite is error-prone) |

### Real-World Patterns

**Make-first enforcement:**
```bash
_redirect() {
  local original="$1" replacement="$2" target="$3"
  jq -n --arg cmd "$replacement" \
       --arg ctx "Redirected \`$original\` → \`$replacement\`. Always use make targets." \
    '{"modifiedArgs":{"command":$cmd},"additionalContext":$ctx}'
  exit 0
}
# In bash tool handler:
_matches "pytest" && _redirect "pytest" "make test" "test"
```

**Domain-specific auto-fix:**
```python
# In a Python preToolUse hook:
fixed_command = re.sub(r"(size_class_counter\s*:\s*)\d+", r"\g<1>16", command)
json.dump({"modifiedArgs": {"command": fixed_command},
           "additionalContext": "Auto-corrected size_class_counter to 16."}, sys.stdout)
```

## `postToolUse` — Result Redaction via `modifiedResult`

After a tool succeeds, `postToolUse` can replace what the LLM sees. This is essential for security — secrets that appear in command output (env vars, config files, API responses) must be stripped before the model processes them:

```bash
# Scan for GitHub PATs in bash output
if echo "$RESULT" | grep -qE 'gh[ps]_[a-zA-Z0-9]{36}'; then
  REDACTED=$(echo "$RESULT" | sed -E 's/gh[ps]_[a-zA-Z0-9]{36}/[REDACTED]/g')
  jq -n --arg r "$REDACTED" \
    '{"modifiedResult":{"textResultForLlm":$r,"resultType":"success"},
      "additionalContext":"Secrets redacted from output."}'
fi
```

The `modifiedResult` object requires both `textResultForLlm` (the sanitized text) and `resultType` (usually `"success"`). The original output is never shown to the model.
> that surfaces visibly to the user. All other hook stderr output is captured by the CLI.

## Debugging Hooks

```bash
# Find the most recent log
ls -lt ~/.copilot/logs/ | head -3

# Check for failures
grep -i "hook\|permission" ~/.copilot/logs/process-<pid>.log

# Count code-127 errors (= script not found)
grep -c "code 127" ~/.copilot/logs/process-<pid>.log
```

- `code 127` → script not found — cwd is repo root, so `./my-hook.sh` fails; use `bash .github/hooks/my-hook.sh`
- `code 1` → script ran but exited with error — test manually: `echo '{"cwd":"...","sessionId":"test","timestamp":0}' | bash .github/hooks/my-hook.sh`
- Zero errors → hooks firing correctly, even if no terminal output is visible

The "Environment loaded" line counts all hooks across all sources (project + plugins):
```
● Environment loaded: 5 custom instructions, 2 MCP servers, 15 hooks, 3 plugins, 25 skills
```

## `--prompt` / `-p` Mode

**v1.0.11:** Hooks do not fire in `--prompt`/`-p` mode. The log shows zero hook entries.

**v1.0.12:** MCP servers defined in `.mcp.json` now start correctly when CWD is the git root. Workspace MCP servers are correctly loaded. Validate hook behavior in interactive mode — `-p` mode hook execution may still be limited.

See `known-pitfalls.md` for details.

## Hook Return Value API (Complete Reference)

All hooks — file-based, SDK programmatic, and extension — can return JSON with these fields. Not all fields apply to every hook type.

### Universal Fields (Any Hook)

| Field | Type | Description |
|-------|------|-------------|
| `additionalContext` | `string` | Injected into the agent's context for the current turn |

### Permission Fields (`preToolUse` / `permissionRequest`)

| Field | Type | Description |
|-------|------|-------------|
| `permissionDecision` | `"allow" \| "deny" \| "ask"` | Allow, deny, or delegate the tool call to the user |
| `permissionDecisionReason` | `string` | Explanation shown to the user/agent when denied |

### Argument Modification Fields (`preToolUse`, v1.0.24+)

| Field | Type | Description |
|-------|------|-------------|
| `modifiedArgs` | `object` | Rewrite specific tool arguments before execution |
| `updatedInput` | `object` | Full replacement of the tool input object |

> `modifiedArgs` patches individual fields; `updatedInput` replaces the entire input. Use `modifiedArgs` for targeted changes, `updatedInput` when you need to restructure the whole call.

### Result Modification Fields (`postToolUse`)

| Field | Type | Description |
|-------|------|-------------|
| `modifiedResult` | `{ textResultForLlm: string, resultType: string }` | Replace what the LLM sees from tool output |

> Use for secret redaction, output filtering, or augmenting tool results with additional context the LLM should see.

### Error Handling Fields (`errorOccurred`)

| Field | Type | Description |
|-------|------|-------------|
| `errorHandling` | `"retry" \| "skip" \| "abort"` | How to handle a recoverable error |
| `retryCount` | `number` | Max retry attempts |
| `userNotification` | `string` | Message displayed to the user |

> `retry` re-executes the failed operation up to `retryCount` times. `skip` continues without the failed operation. `abort` stops the current agent turn.

## Extension Hooks vs File-Based Hooks vs SDK Hooks

| Aspect | File-Based Hooks | Extension Hooks | SDK Programmatic Hooks |
|--------|-----------------|----------------|----------------------|
| **Location** | `.github/hooks/*.json` | `.github/extensions/<name>/extension.mjs` | `createSession({ hooks: {} })` |
| **Language** | Shell scripts (`bash`/`powershell`) | JavaScript (`joinSession()`) | TypeScript (inline functions) |
| **Communication** | JSON on stdin → JSON on stdout | Direct function calls, `session.on()` events | Direct function callbacks |
| **Custom tools** | ❌ | ✅ via `tools` array | ✅ via `defineTool()` |
| **Event streaming** | ❌ | ✅ `session.on(event)` | ✅ `session.on(handler)` |
| **Scope** | Project-local or plugin | Project-local only | SDK app only |
| **Hot-reload** | Automatic per invocation | `extensions_reload` or `/clear` | Restart session |

For full extension documentation, see the `cli-extensions` skill.

## SDK Programmatic Hooks (TypeScript)

SDK hooks use `on`-prefixed camelCase names and are passed in the session config:

```typescript
const session = await client.createSession({
    hooks: {
        onSessionStart:          async (input, invocation) => { /* return { additionalContext: "..." } */ },
        onUserPromptSubmitted:   async (input, invocation) => { return null; },
        onPreToolUse:            async (input, invocation) => { return { permissionDecision: "allow" }; },
        onPostToolUse:           async (input, invocation) => { return null; }, // success only
        onPostToolUseFailure:    async (input, invocation) => { return null; }, // error only
        onAgentStop:             async (input, invocation) => { return null; },
        onSubagentStop:          async (input, invocation) => { return null; },
        onSessionEnd:            async (input, invocation) => { return null; },
        onErrorOccurred:         async (input, invocation) => { return null; },
    },
    onPermissionRequest: async () => ({ kind: "approved" }),
});
```

Return `null` to continue with default behavior. The `invocation` parameter contains the `sessionId`.
