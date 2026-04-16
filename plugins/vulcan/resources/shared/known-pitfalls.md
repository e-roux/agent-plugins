# Known Pitfalls

Accumulated gotchas discovered through use. Read this before giving advice — it prevents repeating known mistakes. Add new entries as they surface.

## Plugin vs Project-Local Confusion

### `plugin.json` does NOT belong in `.agents/`

`.agents/` is for **project-local customization** — skills, instructions, and resources scoped to a single repository. It is not a plugin.

`plugin.json` is a **plugin manifest** — it defines a distributable package installed via `copilot plugin install`. It must live at the plugin root (or `.github/plugin/plugin.json`).

| Concept | Directory | Purpose |
|---|---|---|
| Project-local skills | `.agents/skills/` | Customize AI behavior for this repo |
| Plugin | `my-plugin/plugin.json` | Distributable package with agents, skills, hooks |

If someone asks to "make their repo a plugin," they need `plugin.json` at the repo root — not inside `.agents/`. If they just want to customize copilot for their project, they don't need `plugin.json` at all.

### `.agents/` is not discovered by `plugin.json`

A plugin's `skills` field in `plugin.json` points to directories **relative to the plugin root** (default: `skills/`). The `.agents/skills/` directory is a separate project-local discovery path — it is not part of the plugin packaging system. A plugin cannot reference `.agents/` in its manifest.

## Portable vs GitHub-Specific

### Not everything has a portable alternative

When recommending portable conventions, be honest about gaps:

| Feature | Portable path | GitHub-only fallback |
|---|---|---|
| Skills | `.agents/skills/` | `.github/skills/` |
| Instructions | `AGENTS.md` | `.github/copilot-instructions.md` |
| MCP servers | `.mcp.json` | `.github/mcp.json` |
| Agents | **none** | `.github/agents/` |
| Hooks | **none** | `.github/hooks/hooks.json` |
| Path-scoped instructions | **none** | `.github/instructions/*.instructions.md` |

Don't suggest putting `.agent.md` files in `.agents/agents/` — that path is not discovered by any tool.

## Skill Authoring

### Description is always in context, body is not

The `description` frontmatter is loaded into the agent's context at all times. The SKILL.md body is only injected when the skill triggers. Don't put triggering hints in the body — they won't be seen until it's too late.

### Skills deduplicate by `name`, not by path

If two skills share the same `name` frontmatter field, only the first one found (by loading precedence) is used. The other is silently ignored. This catches people who copy a skill directory and forget to rename the `name` field.

### Skill instructions not persisting across turns (fixed in v1.0.25)

Prior to v1.0.25, skill instructions could silently drop out of the conversation context between turns. If you observed a skill "forgetting" its guidance mid-session, upgrading to v1.0.25 resolves this. Custom instruction files also now correctly preserve special characters like `&` and angle brackets.

## Hook Pitfalls

### Hook stderr output is not shown in the interactive terminal

Hook scripts that write to stderr (`>&2`) do **not** display their output in the terminal
during an interactive session. The CLI captures hook stderr and routes it to the log file
(`~/.copilot/logs/process-<pid>.log`) — it is never rendered to the user.

**Consequence:** Do not use stderr output as the primary communication channel from hooks
to users. Use `additionalContext` in `sessionStart` to pass content to the agent, and
`permissionDecisionReason` in `preToolUse` to show denial messages.

**The only reliable user-visible output from a hook is `permissionDecisionReason`** on a
denied tool call — this IS displayed inline in the session.

### `postToolUse` audit hooks only fire for tools that match your filter

If you write a `postToolUse` hook that filters on `toolName` (e.g., only logs `bash`,
`edit`, `create`), read-side tools (`list`, `glob`, `grep`, `read`, `search`) will not
generate log entries. This is expected — but users often think the hook is broken when
they see an empty audit log after a session that only used read tools.

**Validate** by asking the agent to run a bash command (`ls -la`) — that will trigger
the log write.

### Diagnosing hook problems: always check the log file

The canonical debugging workflow:

```bash
# Find the most recent session log
ls -lt ~/.copilot/logs/ | head -3

# Check for hook failures (exit code 127 = script not found)
grep -i "hook\|127\|permission" ~/.copilot/logs/process-<pid>.log

# Count failures
grep -c "Hook execution failed\|code 127" ~/.copilot/logs/process-<pid>.log
```

Exit code meanings:
- `code 127` → script not found (wrong path — cwd is repo root, not hooks dir)
- `code 1` → script ran but failed (test manually with synthetic JSON on stdin)
- No error entries → hooks fired successfully (even if output was suppressed)

The "Environment loaded" startup line counts all hooks across all sources:
```
● Environment loaded: 5 custom instructions, 2 MCP servers, 15 hooks, 3 plugins, 25 skills
```
Count your hooks in `hooks.json` + installed plugin hook counts to verify the total.



The `cwd` for hook scripts defaults to the repository root, not the hooks directory. Use paths relative to repo root in your scripts (e.g., `bash .github/hooks/scripts/my-hook.sh`, not `bash ./my-hook.sh` assuming you're in `.github/hooks/`).

### Hook output is shown to the user but does not inject into the AI context

A `sessionEnd` hook can print reminders to the terminal, but the AI agent does not see that output. Hooks influence the session through their return values and side effects, not by printing instructions.

> **Exception (v1.0.11+):** `sessionStart` hooks *can* inject context via `additionalContext`. Before v1.0.11 even this was silently ignored.

### Writing plain text to stdout in `sessionStart` causes `write EPIPE`

Since CLI v1.0.11, `sessionStart` hooks that write **plain text** to stdout cause a `✗ Error: write EPIPE` at session startup. The CLI now reads stdout from `sessionStart` hooks expecting `{"additionalContext": "..."}` JSON. When it receives non-JSON text (e.g., an ASCII box banner via `cat << 'EOF'`), the CLI closes the pipe while the hook is still writing → EPIPE in the hook process → the CLI surfaces the error.

**Symptom:** `✗ Error: write EPIPE` appears right after the "Environment loaded" line on every startup.

**Fix:** Replace any `cat << 'EOF' ... EOF` banner in `sessionStart` scripts with a `jq -cn '{additionalContext: "..."}'` call:

```bash
# ✗ Broken — plain text to stdout breaks the pipe in v1.0.11+
cat << 'EOF'
┌──────────────────────────┐
│  MY POLICY ACTIVE        │
└──────────────────────────┘
EOF

# ✓ Correct — output valid additionalContext JSON
jq -cn '{additionalContext: "## My Policy Active\n\nRule 1\nRule 2"}'
```

The policy text is now injected into the agent's context (more useful than a terminal banner anyway).

**Fixing the source is not enough — reinstall the plugin.**
`copilot plugin install` copies the plugin into `~/.copilot/installed-plugins/`. Editing the source
repo does not update the live copy. After any hook change, always reinstall:

```bash
copilot plugin install ./path/to/plugin
```

Verify no installed hook still writes plain text:

```bash
find ~/.copilot/installed-plugins -name "session-start.sh" | xargs grep -l "cat <<" 2>/dev/null
# should return nothing
```

### Flat object hook format does NOT work — only array format works

The old flat format silently fails (hooks never fire):

```json
{ "sessionEnd": { "bash": "bash scripts/cleanup.sh" } }   ← BROKEN — no error, just silent
```

Only the array format with `type: "command"` actually fires:

```json
{ "sessionEnd": [{ "type": "command", "bash": "bash scripts/cleanup.sh" }] }   ← correct
```

**Empirically verified** (CLI v1.0.11): flat format produced zero log output; array format fired correctly.

### `userPromptSubmitted` fires before `sessionStart` in `-p` mode

In non-interactive mode (`copilot -p "..."`), the observed firing order is:
`userPromptSubmitted` → `sessionStart` → `preToolUse` → `postToolUse` → `agentStop` → `sessionEnd`

Do not rely on session initialization state in `userPromptSubmitted`. This ordering anomaly is specific to `-p` mode; interactive mode may differ.

### `toolArgs` has different types in `preToolUse` vs `postToolUse`

In `preToolUse`, `toolArgs` is a **JSON string** (must be parsed):
```bash
COMMAND=$(echo "$INPUT" | jq -r '.toolArgs | fromjson | .command')
```

In `postToolUse`, `toolArgs` is a **parsed JSON object** (access directly):
```bash
COMMAND=$(echo "$INPUT" | jq -r '.toolArgs.command')
```

**Empirically verified** (CLI v1.0.11).

### Plugin hooks are ignored unless declared in `plugin.json`

Placing a hooks file in `.github/hooks/` only works for **project-local** hooks (when users have the plugin repo as their CWD). Plugin hooks — those that load when the plugin is installed — **must** be declared in `plugin.json` via the `hooks` field pointing to a file at the plugin root:

```json
{ "hooks": "hooks/hooks.json" }
```

### Repo hooks in `-p` mode were broken before v1.0.10

`.github/hooks/` files did not fire when using `copilot -p "..."` before v1.0.10. If users report hooks not firing in scripted/CI use, ask them to upgrade.

### `--prompt` / `-p` mode: hooks confirmed NOT firing in v1.0.11

**Empirically verified (v1.0.11, 2026-03-24):** Running `copilot --prompt "..."` produces
**zero hook-related log entries** in `~/.copilot/logs/`. In the same repository, interactive
mode correctly loads and fires hooks (485 observed invocations in one session). The scripts
themselves work correctly when invoked manually.

The v1.0.10 fix only resolved `.github/hooks/` *discovery* in `-p` mode — hook *execution*
in `-p` mode remains broken in v1.0.11.

**v1.0.12 status:** Some fixes landed (MCP servers in `.mcp.json` start correctly, workspace
MCP servers load). Hook execution in `-p` mode should be re-verified against v1.0.12.

**Workaround:** Validate hook behaviour exclusively in interactive mode (`copilot` with no
`--prompt` flag). For CI/scripted use, do not rely on hooks until re-verified.

## LSP Server Pitfalls

### Wrong LSP server subcommand in `lsp-config.json` causes `write EPIPE`

If an LSP server binary is configured with missing or wrong args (e.g. `"args": []` when the
binary requires a subcommand like `server` or `lsp`), the binary prints usage and exits
immediately. The CLI then tries to write the LSP `initialize` request to its already-closed
stdin → `write EPIPE` at session startup — **even if no hooks are configured**.

**Symptom:** `✗ Error: write EPIPE` on every startup across all repos, regardless of plugins
or hooks loaded. The real cause is buried in the process log:

```bash
grep "LSP.*EPIPE\|LSP.*exited\|initialization failed" ~/.copilot/logs/process-*.log | tail -10
```

Look for lines like:
```
LSP python server: initialization failed, cleaning up: Error: write EPIPE
LSP python server: LSP server exited with code 2
```

**Known broken invocations and their fixes:**

| Binary | Broken (`lsp-config.json`) | Fixed |
|---|---|---|
| `zuban` | `"args": []` | `"args": ["server"]` |
| `tsgo` | `"args": []` | `"args": ["lsp"]` |
| `ruff` | `"args": []` | `"args": ["server", "--stdio"]` |

**Quick test:** A correctly configured stdio LSP server must stay running when stdin is kept
open and exit cleanly when stdin closes:

```bash
{ sleep 3; } | timeout 2 zuban server   # must be killed by timeout (exit 124), not self-exit
```

If the server self-exits before timeout, its args are wrong or it is not a stdio LSP server.

**Config location:** `~/.copilot/lsp-config.json` (user-level, applies to all repos).

## Extension Pitfalls

### `onSessionStart` fires on every session transition in extensions

In extensions, `onSessionStart` fires not just once — it can fire on session resume, on `/clear`, and on extension reload. Guard against re-initialization:

```javascript
let initialized = false;
onSessionStart: async () => {
  if (initialized) return;
  initialized = true;
  return { additionalContext: "First-time setup complete." };
},
```

### `session.send()` can cause infinite loops

If `onUserPromptSubmitted` calls `session.send()`, it triggers another `onUserPromptSubmitted`, creating an infinite loop. Break the cycle with `setTimeout`:

```javascript
onUserPromptSubmitted: async (input) => {
  if (shouldInject(input.prompt)) {
    setTimeout(() => session.send({ prompt: "Follow-up task" }), 0);
  }
},
```

### Extensions conflict with apps that claim the same port (e.g., Telegram bots)

Extensions that start HTTP servers or bind to ports can conflict with other extensions or local services. Use dynamic port allocation and check for port availability.

### Windows signal handling differs for extension child processes

On Windows, `SIGTERM`/`SIGINT` handling for forked extension processes works differently. Extensions that need clean shutdown should listen for `session.on("session.shutdown")` rather than relying on process signals.

### `skipPermission: true` tools bypass ALL hooks

Tools registered with `skipPermission: true` in extensions are invisible to `onPreToolUse` hooks and `onPermissionRequest` handlers. Audit-only hooks will miss these tool calls entirely. Only use for genuinely safe read-only operations.

### Extensions require `@github/copilot-sdk` but no `npm install`

The SDK is auto-resolved by the CLI runtime. Do NOT add `@github/copilot-sdk` to a `package.json` in the extension directory — version mismatches between your installed version and the CLI's bundled version will cause errors.

## SDK v0.2.x Pitfalls

### `autoRestart` silently removed — no runtime error

The `autoRestart` option in `CopilotClientOptions` still type-checks but has **no effect** in v0.2.0+. It was never fully implemented. If you relied on it for crash recovery, you must implement your own restart logic.

### Python/Go SDK breaking changes — TypeScript is safe

SDK v0.2.0 has major breaking changes for **Python** (new `SubprocessConfig`/`ExternalServerConfig` classes, keyword arguments for `create_session`/`send`) and **Go** (`Client.Start()` context no longer kills the CLI process, `LogOptions.Ephemeral` changed to `*bool`). TypeScript has no breaking API changes.

If your plugin's skills document multi-language SDK patterns, update the Python/Go examples to use the new APIs.

### Node `onElicitationRequest` changed to a single `ElicitationContext` in v0.2.1

Node SDK examples that still use `onElicitationRequest(request, invocation)` are now stale. In v0.2.1 the handler receives a single `context` object that carries both the session metadata and the elicitation request payload.

**Symptom of mismatch:** TypeScript examples compile or type-check incorrectly after upgrading the SDK, and handlers that read `request.message` / `invocation.sessionId` separately stop matching the public API.

### Prefer high-level `commands` and `session.ui.*` before raw RPC in v0.2.1

SDK v0.2.1 promotes slash commands and structured UI elicitation across all four SDKs. For common confirm/select flows, prefer `commands`, `session.ui.confirm()`, and `session.ui.select()` over custom wrappers or low-level `session.rpc.ui.elicitation()`.

**Why it matters:** low-level RPC calls still work, but they make simple interactions harder to read and are easier to get wrong when the higher-level API now exists.

### `sessionFs` available across all SDKs since v0.2.2

The `sessionFs` adapter was Node-only in v0.2.1. Since v0.2.2, it is available across all four SDKs (Node, Python, Go, .NET), letting any application redirect per-session storage (event logs, large outputs) to a custom backend.

**Symptom of mismatch:** guides written for v0.2.1 state `sessionFs` is Node-only — this is no longer true. Update cross-language examples to show the feature is now universally available.

### Structured tool results now stay structured in v0.2.1

Node, Go, and Python SDK integrations now receive structured tool results over RPC as objects instead of pre-stringified JSON blobs. Audit and redaction code should read fields like `resultType` and `textResultForLlm` directly instead of reparsing strings.

**Symptom of mismatch:** hooks or logging code stringify / parse `toolResult` repeatedly, or examples incorrectly treat `input.toolResult` as a plain string.

### `systemMessage.mode: "customize"` requires exact section names

The 10 section names (`identity`, `tone`, `tool_efficiency`, `environment_context`, `code_change_rules`, `guidelines`, `safety`, `tool_instructions`, `custom_instructions`, `last_instructions`) must be spelled exactly. Misspelled section names are silently ignored — no error is raised. Double-check section names in your config.

### `enableConfigDiscovery` merges with explicit config — explicit wins on collision (v0.2.2)

Setting `enableConfigDiscovery: true` in session config makes the runtime discover `.mcp.json` and skill directories from the working directory. Discovered settings are **merged** with explicitly provided values; explicit values win on name collision. This is useful for zero-config SDK apps but can cause surprises if the working directory has an `.mcp.json` you didn't expect.

**Symptom of mismatch:** an SDK app loads unexpected MCP servers or skills because the working directory has config files from a different project. Either set `enableConfigDiscovery: false` (default) or control the working directory.

### `preToolUse` hooks can now modify tool arguments (v1.0.24)

In CLI v1.0.24, `preToolUse` hooks respect `modifiedArgs`, `updatedInput`, and `additionalContext` fields in the hook response. This means hooks can silently rewrite tool arguments before the tool executes. Previously these fields were ignored.

**Symptom of mismatch:** a preToolUse hook script that returns `modifiedArgs` expecting argument rewriting does nothing on CLI < 1.0.24. Ensure the minimum CLI version is documented when using this feature.

### Custom agent `model` field now accepts display names (v1.0.24)

The `model` field in `.agent.md` frontmatter now accepts display names and vendor suffixes from VS Code (e.g., "Claude Sonnet 4.5", "GPT-5.4 (copilot)") in addition to model IDs. On older CLI versions, only model IDs are accepted.

### New RPC methods are experimental — APIs may change

The `session.rpc.skills.*`, `session.rpc.mcp.*`, `session.rpc.extensions.*`, `session.rpc.plugins.*`, `session.rpc.ui.elicitation()`, `session.rpc.shell.*`, and `session.log()` APIs are flagged as experimental. They lack friendly wrappers and their signatures may change in future releases.

### `skipPermission: true` on tools bypasses ALL permission checks

Setting `skipPermission: true` on a tool definition means `onPreToolUse` hooks and `onPermissionRequest` handlers are **never called** for that tool. Use only for genuinely safe, read-only operations. Audit-only hooks will miss these tool calls.

### `.claude/settings.json` is a new config source (v1.0.12+)

CLI v1.0.12 reads `.claude/settings.json` and `.claude/settings.local.json` as additional repo config sources. If a project has conflicting settings between `.claude/settings.json` and `.github/` convention files, the merge behavior may produce unexpected results. Add `.claude/settings.local.json` to `.gitignore` for personal overrides.

### Config settings now prefer camelCase names (v1.0.15+)

Settings keys `askUser`, `autoUpdate`, `storeTokenPlaintext`, `logLevel`, `skillDirectories`, and `disabledSkills` now use **camelCase** as the canonical name. The old snake_case names (`ask_user`, `auto_update`, etc.) still work as aliases, but new configs should use camelCase to match the documented format.

**Symptom of mismatch:** Settings written with snake_case keys may produce deprecation warnings in future versions even though they function correctly today.

```json
{
  "skillDirectories": ["~/.agents/skills"],
  "disabledSkills": ["experimental-feature"],
  "logLevel": "debug"
}
```

### CLI-built-in skills can make custom skills redundant (v1.0.17+)

Before you create a repo or plugin skill, check `/skills list`. The CLI now ships built-in skills, so a custom skill should add project-specific behavior rather than duplicate a guide users already have by default.

## Hook Design Pitfalls

### Deny-and-retry is a DX anti-pattern — prefer redirect-and-teach

When a `preToolUse` hook denies a tool call, the agent retries — often with a different wrong approach. After 2–3 denials the agent gives up or halluccinates a workaround. This creates a frustrating developer experience.

**Better pattern (v1.0.24+):** Use `modifiedArgs` to silently redirect the command to the correct one, plus `additionalContext` to explain WHY. The agent sees the correct command succeed and learns the pattern within the session:

```bash
# Instead of: _deny "Direct pytest is forbidden. Use make test."
# Do:
jq -n --arg cmd "make test" --arg ctx "Redirected pytest → make test. Always use make targets." \
  '{"modifiedArgs":{"command":$cmd},"additionalContext":$ctx}'
```

**When to still deny:**
- Dangerous/irreversible operations (DROP TABLE, secret commits, main push)
- Complex rewrites where `modifiedArgs` would be error-prone
- Violations that need human judgment (ambiguous domain rules)

### `modifiedArgs` without `additionalContext` teaches nothing

If you redirect `pytest` → `make test` silently (no `additionalContext`), the agent never learns. It worked! So it tries `pytest` again next turn. Always pair `modifiedArgs` with `additionalContext` explaining the rule.

### `modifiedResult` is defense-in-depth for secrets, not a replacement for `preToolUse`

`postToolUse` + `modifiedResult` redacts secrets from tool OUTPUT. This complements `preToolUse` secret guards on INPUT. You need both:
- `preToolUse` blocks secrets going IN (code, config files)
- `postToolUse` strips secrets coming OUT (env dumps, config reads, API responses)

Neither alone is sufficient. A `cat .env` command passes `preToolUse` (it's just reading) but its output contains secrets that `postToolUse` must redact.

## Hook Pitfalls (v1.0.26+)

### Plugin hooks now receive `PLUGIN_ROOT` env vars (v1.0.26)

Plugin hooks receive three new env vars: `PLUGIN_ROOT`, `COPILOT_PLUGIN_ROOT`, and `CLAUDE_PLUGIN_ROOT`, all pointing to the plugin's installation directory. If your hook scripts hard-code relative paths from `CLAUDE_PLUGIN_DATA` to reach the plugin root, prefer `COPILOT_PLUGIN_ROOT` for forward-compatible path resolution.

### `notification` hook only fires when a prompt is actually shown (v1.0.26)

The permission prompt `notification` hook previously fired even when approvals were auto-granted (e.g., via `/yolo` or `permissionDecision: "allow"`). Since v1.0.26, it only fires when a prompt is actually displayed to the user. If your hook relied on notification events for audit logging of all permission decisions, move that logic to a `preToolUse` or `permissionRequest` hook instead.

### Duplicate instruction files are deduplicated (v1.0.26)

If `copilot-instructions.md` and `CLAUDE.md` (or similar files) have identical content, the CLI now sends only one copy to the model, reducing wasted tokens per turn. This is transparent to users, but hook scripts that inspect instruction counts in the context should account for deduplication.

### Context compaction checkpoint boundary fix (v1.0.26)

Agent sessions no longer fail with unrecoverable errors when context compaction splits a tool call across a checkpoint boundary. If you previously saw sessions die during long-running autonomous tasks, this fix addresses the root cause.

## Hook Pitfalls (v1.0.19+)

### PascalCase hook event names produce snake_case payloads (v1.0.21+)

Hooks configured with PascalCase event names (e.g., `PreToolUse`) now receive VS Code-compatible
snake_case payloads with `hook_event_name`, `session_id`, and ISO 8601 timestamps. If your hook
scripts parse payload fields by name, they must handle the snake_case field names when registered
under PascalCase event names. This normalization only applies to PascalCase registrations — hooks
using camelCase event names (`preToolUse`) continue to receive the original payload format.

### `.vscode/mcp.json` and `.devcontainer/devcontainer.json` removed (v1.0.22+)

CLI v1.0.22 drops `.vscode/mcp.json` and `.devcontainer/devcontainer.json` as MCP server config
sources. The CLI now **only** reads `.mcp.json` at the project root. A migration hint appears when
`.vscode/mcp.json` is detected without `.mcp.json`.

**Symptom:** MCP servers defined in `.devcontainer/devcontainer.json` or `.vscode/mcp.json` silently
stop loading after upgrading to v1.0.22.

**Fix:** Move server definitions to `.mcp.json` at the project root:

```json
{
  "servers": {
    "my-server": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-example"],
      "env": { "TOKEN": "${TOKEN}" }
    }
  }
}
```

### `sessionStart`/`sessionEnd` hooks fire once per session (v1.0.22+)

In interactive mode, `sessionStart` and `sessionEnd` hooks now fire **once per session** instead of
once per prompt. This is a behavioral correction — previous versions could fire these hooks multiple
times in a single session.

**Impact:** Hooks that relied on `sessionStart` firing on every prompt (e.g., for per-turn context
injection) will now only fire once. Move per-turn logic to `userPromptSubmitted` instead.

### Custom agents can eagerly load skills (v1.0.22+)

Custom agents can now declare a `skills` field in their frontmatter to eagerly load specific skill
content into the agent context at startup, rather than waiting for the skill to trigger on demand.

### `/mcp enable`/`/mcp disable` now persist across sessions (v1.0.19+)

Previously, enabling or disabling an MCP server with `/mcp enable` or `/mcp disable` was
session-scoped and reset on restart. From v1.0.19 onward, these commands persist their state.
If you disabled a server for debugging and forgot about it, it stays disabled in future sessions.

**Symptom:** An MCP server silently missing from `/mcp show` in new sessions after you disabled
it in a previous session. Re-enable with `/mcp enable <name>`.

## Hook Pitfalls (v1.0.15+)

### `preToolUse` and `permissionRequest` solve different problems (v1.0.16+)

`preToolUse` runs before the runtime decides how to handle the tool call; use it for policy decisions based on `toolName` / `toolArgs`. `permissionRequest` is a later hook for workflows that want to participate when the runtime is about to ask for approval.

**Impact on design:** treat `preToolUse` as the policy gate and `permissionRequest` as the approval-automation layer. They are complementary, not interchangeable.

### Explicit `allow` suppresses the prompt (v1.0.18+)

Returning `{ "permissionDecision": "allow" }` is now an active approval path, not just a no-op. If you only want to audit or log tool activity, omit hook output instead of returning `allow`.

### `notification` hooks are async side channels, not policy hooks (v1.0.18+)

The new `notification` hook fires asynchronously for shell completion, permission prompts, elicitation dialogs, and agent completion. It is useful for desktop/webhook notifications and passive telemetry, but it is the wrong place to enforce policy or inject context.

### `postToolUse` now fires on success only — add `postToolUseFailure` for errors

Before v1.0.15, `postToolUse` fired after every tool call regardless of outcome. From v1.0.15 onwards:
- `postToolUse` fires **only when the tool succeeds**
- `postToolUseFailure` fires **only when the tool errors**

**Impact on audit hooks:** If your `postToolUse` hook is used to log all tool activity, it will now silently miss failed tool calls. Add a `postToolUseFailure` handler to maintain complete coverage:

```bash
# In a file-based hook: register both event types
# hooks.json
{
  "postToolUse": [{ "type": "command", "bash": "bash .github/hooks/scripts/audit.sh" }],
  "postToolUseFailure": [{ "type": "command", "bash": "bash .github/hooks/scripts/audit-failure.sh" }]
}
```

The `postToolUseFailure` input includes `toolName`, `toolArgs` (parsed object), and `error` (`{message, name, stack}`).

## Eager Loading vs Agent-Private Skills (v1.0.22)

### Eager loading ≠ reduced global skill count

The `skills` frontmatter field in `.agent.md` files **does NOT hide skills from the global list**. It only pre-loads the skill content into that agent's context at startup.

All skills registered via `plugin.json`'s `skills` path remain globally visible in `/skills list` and count towards the total loaded skills displayed in the startup banner — regardless of whether they are also eagerly loaded by a specific agent.

**Root cause:** `Xxe()` in the CLI looks up agent skill names against `this._loadedSkills` (all globally registered skills). A skill must be globally registered to be eagerly loadable. There is no mechanism to register a skill exclusively for a single agent.

**Skill count breakdown (CLI v1.0.22):**
| Source | Count | Location |
|--------|-------|----------|
| Built-in | 1 | CLI installation |
| Personal | variable | `~/.copilot/skills/`, `~/.agents/skills/` |
| Plugin | sum of all plugin skills | plugin `skills/` dirs |

The count shown at startup (e.g., `24 skills`) includes ALL sources. To reduce it, you must either merge/remove plugin skills, remove personal skills, or wait for CLI support for agent-private skill registration.

### GitHub Releases MUST include compiled binaries

A Makefile `release` target that creates a GitHub release without attaching pre-compiled binaries is **non-functional** — the auto-update wrapper script (`bin/<name>.sh`) queries `gh api repos/OWNER/REPO/releases/latest` and then calls `gh release download ... -p <asset-name>`. If no binary assets are attached, the download silently fails and the script falls back to build-from-source.

**Rule:** always attach the cross-compiled binaries when creating the release:

```makefile
release:
	for platform in darwin/arm64 darwin/amd64 linux/amd64 linux/arm64; do \
	  os=$${platform%%/*}; arch=$${platform##*/}; \
	  GOOS=$$os GOARCH=$$arch go build -ldflags="-s -w" -o bin/my-server-$$os-$$arch ./cmd/...; \
	done
	gh release create "v$(VERSION)" bin/my-server-* --notes-file CHANGELOG.md --latest
```

Do NOT create the release first and upload assets separately in CI — the wrapper may check for updates and find an empty release before assets finish uploading.

## Model Removal Pitfalls

### gpt-5.1-codex, gpt-5.1-codex-mini, gpt-5.1-codex-max removed (v1.0.15+)

These three model IDs no longer exist. Any code, config, or documentation referencing them must be updated:

| Removed                  | Replacement suggestion           |
|--------------------------|----------------------------------|
| `gpt-5.1-codex`          | `gpt-5.2-codex` or `gpt-5.3-codex` |
| `gpt-5.1-codex-mini`     | `gpt-5.4-mini` or `gpt-5-mini`  |
| `gpt-5.1-codex-max`      | `gpt-5.2` or `gpt-5.4`          |

Calling `setModel("gpt-5.1-codex")` or passing it in `createSession` will produce an error at runtime. Search your codebase: `grep -r "gpt-5.1-codex" .`

## Dual-Tool (Copilot CLI + Claude Code) Pitfalls

### `.agents/skills/` is NOT explicitly documented in Claude Code

Copilot CLI labels `.agents/skills/` as "Portable" (priority 2) and claims cross-tool compatibility via the [Agent Skills](https://agentskills.io) standard. However, Claude Code's documentation only lists `.claude/skills/` as the project skill discovery path. While Claude Code says it "follows the Agent Skills standard", this refers to the **SKILL.md format**, not necessarily the `.agents/` discovery path.

**Use `.claude/skills/`** for project skills when targeting both tools — it is the only path explicitly documented and verified in both.

### `CLAUDE.md` needed as bridge for `AGENTS.md` in Claude Code

Copilot CLI reads `AGENTS.md` natively. Claude Code does NOT — it reads `CLAUDE.md`. To share instructions, create a thin `CLAUDE.md` containing `@AGENTS.md` (the `@` import syntax). Claude Code resolves the import at session start. Without this bridge file, Claude Code ignores `AGENTS.md` entirely.

### Hook event naming differs: camelCase vs PascalCase

Copilot CLI uses camelCase: `preToolUse`, `sessionStart`, `postToolUse`.
Claude Code uses PascalCase: `PreToolUse`, `SessionStart`, `PostToolUse`.

Using the wrong case silently results in hooks never firing. Hook configuration JSON structure also differs — Claude Code requires a `matcher` field and wraps hooks in an extra `hooks` array per matcher. Share the **scripts**, not the wiring config.

### Hook input payload field names differ

Copilot CLI hook stdin uses `toolName` and `toolInput`.
Claude Code hook stdin uses `tool_name` and `tool_input`.

Scripts that inspect the payload must handle both:

```bash
TOOL=$(echo "$INPUT" | jq -r '.tool_name // .toolName')
```

### Plugin manifest paths — two files needed (schemas differ)

`.claude-plugin/plugin.json` is discovered by BOTH tools but they require different content:
- **Claude Code** rejects `agents`, `skills`, `hooks` string paths and unknown keys like `_meta` — use a minimal manifest (name/description/version/author/license/keywords only)
- **Copilot CLI** requires `agents`, `skills`, `hooks` string paths to load components

**Solution: two files, each tool reads its own**
- `.claude-plugin/plugin.json` — minimal (Claude Code reads this)
- `plugin.json` (root) — full with all Copilot CLI fields (Copilot CLI reads root as priority 2, beats priority 4)

Claude Code auto-discovers agents/skills/hooks from `agents/`, `skills/`, and `hooks/hooks.json` without any manifest reference.

### Plugin hooks cannot share one file — split required

Claude Code rejects camelCase event names (`sessionStart`) in `hooks/hooks.json`. Copilot CLI uses camelCase. Two separate hook files are required:
- `hooks/hooks.json` — PascalCase only, auto-discovered by Claude Code
- `hooks/hooks.copilot.json` — camelCase only, referenced in root `plugin.json` as `"hooks": "hooks/hooks.copilot.json"`

Shared scripts (`scripts/`) can be called from both files. Use `$CLAUDE_PLUGIN_ROOT` (set by both tools).

### `claude plugin install OWNER/REPO` does not work

Claude Code does NOT support direct `OWNER/REPO` install like Copilot CLI. It requires a **marketplace**. To install plugins in Claude Code:

1. Create a marketplace repo with `.claude-plugin/marketplace.json`
2. Add it: `claude plugin marketplace add OWNER/marketplace-repo`
3. Install: `claude plugin install plugin-name@marketplace-name`

Marketplace-based install is the only method that works in BOTH tools.

### Agent files use different extensions and paths — RESOLVED

~~Previously, `.github/agents/` (Copilot CLI) and `.claude/agents/` (Claude Code) had no overlap.~~

**Update:** Copilot CLI now discovers `.claude/agents/` for project agents. Use `.claude/agents/` as the DRY path with the `.agent.md` extension (required by Copilot CLI, accepted by Claude Code since `*.agent.md` matches `*.md` glob).
