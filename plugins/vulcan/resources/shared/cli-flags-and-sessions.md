# CLI Flags, Sessions, and Remote Access

## CLI Invocation Modes

### Interactive (default)

```bash
copilot                    # start interactive session
copilot "fix the bug"      # start session with initial prompt
```

### Programmatic / Non-Interactive

```bash
copilot -p "list all TODO comments"     # single prompt, exit after response
copilot --prompt "explain auth.ts"      # long form

copilot -p "run tests" --output-format=json   # JSONL streaming output for scripts
copilot -p "deploy" --autopilot               # no confirmations, fully autonomous
```

### Autonomous Mode

```bash
copilot --autopilot                          # auto-approve all tool calls
copilot --allow-all                          # alias for --autopilot
copilot --max-autopilot-continues 50         # limit agent turns (default: varies)
```

### Planning Mode (v1.0.23+)

```bash
copilot --plan                # enter plan mode — agent plans before acting
copilot --mode plan           # equivalent
copilot --mode execute        # default — agent acts directly
```

## Session Management

### Continue / Resume

```bash
copilot --continue                   # resume most recent session
copilot --resume=<session-id>        # resume specific session by ID
```

Sessions persist tool history, file context, and conversation state. The agent picks up exactly where it left off.

### Session Sharing and Export

```bash
/share html              # export session as self-contained interactive HTML
                         # shows a file:// URL and supports Ctrl+X O to open the file directly (v1.0.25)
```

### Remote Session Control (v1.0.25+)

You can remote control your CLI sessions from another device or process (renamed from "steering" to "remote control" in v1.0.26):

```bash
copilot --remote         # start in remote-controllable mode
/remote                  # enable remote control in an existing session
```

This extends the earlier remote session URL feature (v1.0.10) with full bidirectional control.

### Remote Session URLs

When using Copilot CLI over SSH or remote terminals, the CLI generates **clickable URLs** that open the session in a browser on another device (v1.0.10+). This enables:

- Managing a CLI session from your phone or tablet
- Pair-programming across machines
- Checking on long-running autonomous sessions from any browser

## Agent Client Protocol (ACP)

```bash
copilot --acp              # start in Agent Client Protocol mode
```

ACP bridges the CLI to IDE clients (VS Code, JetBrains). The CLI acts as an agent backend while the IDE provides the UI. This is how Copilot Chat in VS Code connects to the CLI's tool ecosystem.

Since v1.0.25, ACP clients can provide MCP servers (stdio, HTTP, SSE) when starting or loading sessions, enabling IDE-hosted MCP servers to be forwarded into the CLI runtime.

## Built-In Slash Commands

### Session Control

| Command | Description |
|---------|-------------|
| `/clear` | Start new session (reloads extensions, resets context) |
| `/compact` | Compress conversation context (frees token budget) |
| `/model` | Switch active model mid-session |
| `/mode` | Toggle between plan and execute modes |

### Agent Collaboration

| Command | Description |
|---------|-------------|
| `/delegate` | Hand off current task to Copilot cloud agent running on GitHub infrastructure |
| `/fleet` | Launch parallel multi-agent execution — orchestrator decomposes task, dispatches sub-agents |
| `/pr` | Create, manage, or interact with pull requests from the CLI |

### Utility

| Command | Description |
|---------|-------------|
| `/extensions` | View, enable, disable extensions |
| `/share html` | Export session as interactive HTML (Ctrl+X O to open, v1.0.25) |
| `/changelog` | Browse CLI changelog (`last <N>`, `since <version>`, `summarize`) |
| `/help` | Show available commands |
| `/env` | Show loaded environment details: instructions, MCP servers, skills, agents, plugins (v1.0.25) |
| `/ask` | Ask a quick question without affecting conversation history (v1.0.27) |

### `/fleet` — Parallel Multi-Agent

`/fleet` launches an orchestrator that:
1. Decomposes the task into independent subtasks
2. Spawns sub-agents (each with its own context)
3. Runs them in parallel
4. Merges results

Best for: bulk refactoring across many files, parallel test investigation, multi-service changes.

### `/delegate` — Cloud Agent

`/delegate` (or `&` prefix) sends the task to a Copilot cloud agent running on GitHub infrastructure:
- The cloud agent has access to GitHub repos, issues, PRs
- It runs asynchronously — you get a link to track progress
- Results appear as PR drafts or issue comments

### `/pr` — Pull Request Workflows

`/pr` enables PR creation and management without leaving the CLI:
- Creates PRs with branch, title, body auto-generated
- Can review, comment on, and merge PRs

## File Mentions (`@` syntax)

Reference files directly in prompts:

```
@src/auth.ts          # relative to workspace root
@~/dotfiles/.zshrc    # home directory expansion
@/etc/nginx.conf      # absolute path
@../sibling/file.ts   # relative parent traversal
```

The CLI reads and attaches file content to the prompt automatically.

## Background Agents

### `write_agent` — Multi-Turn Conversations

Background agents launched via the `task` tool can receive follow-up messages:

```
write_agent(agent_id, "now also fix the edge case for empty input")
```

This enables multi-turn conversations with background agents without blocking the main session.

### Sub-Agent Lifecycle

When the CLI spawns sub-agents (via `/fleet` or `task`), hooks can intercept:

- `subagentStart` — inject context into the sub-agent before it runs (v1.0.7+)
- Each sub-agent has its own tool set and context window

## Experimental Features

### Embedding-Based Instruction Retrieval

The CLI can dynamically select skills and MCP servers per turn based on semantic similarity between the user prompt and available instruction content. Enabled when configured (v1.0.5+).

### Critic Agent

Automatically reviews plans and implementations using a complementary model. The critic provides a second opinion before the agent proceeds (v1.0.18+, experimental).

## Environment Variables

| Variable | Description |
|----------|-------------|
| `COPILOT_CLI_MODEL` | Override default model |
| `COPILOT_CLI_CONFIG_DIR` | Custom config directory |
| `GITHUB_TOKEN` | Authentication token (auto-detected from `gh auth`) |
| `COPILOT_CLI_LOG_LEVEL` | Logging verbosity (`debug`, `info`, `warn`, `error`) |
