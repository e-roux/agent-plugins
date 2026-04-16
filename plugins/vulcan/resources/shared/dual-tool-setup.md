# Dual-Tool DRY Configuration (Copilot CLI + Claude Code)

When a repository is used with **both** GitHub Copilot CLI (`copilot`) and Claude Code (`claude`), the goal is to share as much configuration as possible. This guide maps every configuration surface to its DRY strategy.

## Quick Reference

| Feature | DRY path | Strategy |
|---------|----------|----------|
| Instructions | `AGENTS.md` | Shared body; thin `CLAUDE.md` imports it |
| Skills | `.claude/skills/NAME/SKILL.md` | Identical format, discovered by both |
| MCP servers | `.mcp.json` | Identical format, discovered by both |
| Settings | `.claude/settings.json` | Shared subset of keys |
| Agents (project) | `.claude/agents/*.agent.md` | **DRY** — both tools now discover `.claude/agents/` |
| Agents (plugin) | `agents/*.agent.md` | Same dir, `.agent.md` works in both |
| Hooks | `.github/hooks/` + `.claude/settings.json` | Share scripts, tool-specific wiring |
| Plugin manifest | `.claude-plugin/plugin.json` | **Single file** — both tools discover it |
| Plugin marketplace | `.claude-plugin/marketplace.json` | **Single file** — both tools discover it |

## Instructions — `AGENTS.md` as single source of truth

Both tools load project instructions at session start, but from different files:

| Tool | Native file | Reads `AGENTS.md`? |
|------|------------|---------------------|
| Copilot CLI | `AGENTS.md` | Yes — native |
| Claude Code | `CLAUDE.md` or `.claude/CLAUDE.md` | No — must import |

**DRY strategy:** Write ALL project instructions in `AGENTS.md`. Create a thin `CLAUDE.md` that imports it:

```markdown
@AGENTS.md
```

Add Claude Code–specific overrides (if any) below the import:

```markdown
@AGENTS.md

## Claude Code

Use plan mode for changes under `src/billing/`.
```

Claude Code loads the imported `AGENTS.md` content at session start. The `@` import syntax resolves at load time and supports relative paths, `~/`, and recursive imports up to 5 levels deep.

For path-scoped rules that only Claude Code supports, use `.claude/rules/*.md` alongside the shared `AGENTS.md`.

## Skills — `.claude/skills/` is the DRY path

Both tools discover skills in `.claude/skills/` and use the same `SKILL.md` format (the [Agent Skills](https://agentskills.io) open standard).

| Tool | Discovery paths (project) | DRY path |
|------|--------------------------|----------|
| Copilot CLI | `.github/skills/` > `.agents/skills/` > `.claude/skills/` | `.claude/skills/` (priority 3) |
| Claude Code | `.claude/skills/` | `.claude/skills/` (native) |

**DRY strategy:** Place all project skills in `.claude/skills/NAME/SKILL.md`. Both tools discover them. The `SKILL.md` format is identical — `name`, `description`, and markdown body.

```
.claude/
└── skills/
    ├── deploy/
    │   └── SKILL.md
    └── code-review/
        └── SKILL.md
```

### Frontmatter compatibility

| Field | Copilot CLI | Claude Code | Shared? |
|-------|-------------|-------------|---------|
| `name` | ✅ | ✅ | Yes |
| `description` | ✅ | ✅ | Yes |
| `when_to_use` | ✅ | ✅ | Yes |
| `disable-model-invocation` | ✅ | ✅ | Yes |
| `user-invocable` | ✅ | ✅ | Yes |
| `allowed-tools` | ✅ | ✅ | Yes |
| `model` | ✅ | ✅ | Yes |
| `context` | ✅ | ✅ (`fork`) | Yes |
| `agent` | ✅ | ✅ | Yes |
| `effort` | ❌ | ✅ | Claude only (ignored by Copilot) |
| `hooks` | ❌ | ✅ | Claude only (ignored by Copilot) |
| `paths` | ❌ | ✅ | Claude only (ignored by Copilot) |
| `shell` | ❌ | ✅ | Claude only (ignored by Copilot) |
| `argument-hint` | ❌ | ✅ | Claude only (ignored by Copilot) |

Unknown frontmatter fields are silently ignored by both tools, so Claude-only fields in a shared `SKILL.md` are safe — they simply have no effect in Copilot CLI.

### Note on `.agents/skills/` vs `.claude/skills/`

The Copilot CLI labels `.agents/skills/` as "Portable" (priority 2) and `.claude/skills/` as "Claude Code" (priority 3). However, Claude Code's documentation only lists `.claude/skills/` as a discovery path. While Claude Code states it follows the Agent Skills standard (which defines `.agents/skills/`), the path is not explicitly documented.

**Recommendation:** Use `.claude/skills/` — it is explicitly documented and verified in both tools.

If you also need Cursor/Windsurf compatibility, consider symlinking:

```bash
ln -s .claude/skills .agents/skills
```

## MCP Servers — `.mcp.json` is fully shared

Both tools read `.mcp.json` at the project root with the same format.

```json
{
  "mcpServers": {
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": { "DATABASE_URL": "${DATABASE_URL}" }
    }
  }
}
```

Environment variable expansion (`${VAR}`, `${VAR:-default}`) works in both tools.

| Scope | Copilot CLI | Claude Code |
|-------|-------------|-------------|
| Project | `.mcp.json` | `.mcp.json` |
| User | `~/.copilot/mcp-config.json` | `~/.claude.json` (mcpServers section) |
| Plugin | Plugin MCP configs | Plugin `.mcp.json` or inline in `plugin.json` |

User-level MCP configs are tool-specific — no DRY path exists there.

## Settings — `.claude/settings.json` shared subset

Copilot CLI reads `.claude/settings.json` and `.claude/settings.local.json` as additional config sources (v1.0.12+). Claude Code uses them natively.

The shared key surface is limited. Both tools understand permission-style settings, but each has its own key namespace. The primary shared value is hook and permission configuration — test empirically when relying on cross-tool settings.

## Agents — `.claude/agents/` is now the DRY path

Copilot CLI now discovers `.claude/agents/` for project-level agents alongside its native `.github/agents/` path:

| Priority | Location | Copilot CLI | Claude Code |
|----------|----------|-------------|-------------|
| 1 | `~/.copilot/agents/` | ✅ | ❌ |
| 2 | `.github/agents/*.agent.md` | ✅ | ❌ |
| 3 | `~/.claude/agents/` | ✅ | ✅ |
| 4 | **`.claude/agents/*.agent.md`** | **✅** | **✅** |
| 5 | Plugin `agents/` dirs | ✅ | ✅ |

**DRY strategy:** Place project agents in `.claude/agents/` with the `.agent.md` extension. Copilot CLI requires the `.agent.md` extension for agent discovery. Claude Code accepts any `*.md` file — since `.agent.md` ends with `.md`, it matches.

```
.claude/
└── agents/
    ├── reviewer.agent.md    # Discovered by both tools
    └── db-analyst.agent.md  # Discovered by both tools
```

### Frontmatter compatibility

| Field | Copilot CLI | Claude Code | Shared? |
|-------|-------------|-------------|---------|
| `name` | ✅ | ✅ | Yes |
| `description` | ✅ | ✅ | Yes |
| `tools` | ✅ (list format) | ✅ (comma-separated string) | ⚠️ Use list format |
| `model` | ✅ | ✅ | Yes |
| `skills` | ✅ | ✅ | Yes |
| `mcp-servers` | ✅ | ❌ (`mcpServers`) | Use `mcpServers` for Claude |
| `disallowedTools` | ✅ | ✅ | Yes |
| `maxTurns` | ❌ | ✅ | Claude only |
| `permissionMode` | ❌ | ✅ | Claude only |
| `hooks` | ❌ | ✅ | Claude only |
| `memory` | ❌ | ✅ | Claude only |
| `effort` | ❌ | ✅ | Claude only |
| `isolation` | ❌ | ✅ | Claude only |
| `background` | ❌ | ✅ | Claude only |

Unknown frontmatter fields are silently ignored by both tools.

## Hooks — no common format, share scripts

Hook configuration formats differ completely:

| Aspect | Copilot CLI | Claude Code |
|--------|-------------|-------------|
| Location | `.github/hooks/*.json` or plugin `hooks.json` | `.claude/settings.json` `hooks` section |
| Event naming | camelCase: `preToolUse`, `sessionStart` | PascalCase: `PreToolUse`, `SessionStart` |
| Format | `{ "hooks": { "event": [{ "type": "command", "bash": "..." }] } }` | `{ "hooks": { "Event": [{ "matcher": "...", "hooks": [{ "type": "command", "command": "..." }] }] } }` |
| Matcher | No matcher (all tool calls hit the hook) | Matcher filters by tool name / regex |
| Return value | JSON on stdout: `additionalContext`, `permissionDecision`, `modifiedArgs` | JSON on stdout: `hookSpecificOutput` with `permissionDecision`, `decision` |
| Script field | `"bash": "bash scripts/check.sh"` | `"command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/check.sh"` |

**DRY strategy — share the scripts, not the wiring:**

Keep hook scripts in a shared location (e.g., `scripts/` at repo root). Both tools' hook configs reference the same scripts:

```
scripts/
├── audit-prompt.sh        # shared script logic
├── block-dangerous.sh     # shared script logic
```

Copilot CLI hook config (`.github/hooks/hooks.json`):
```json
{
  "hooks": {
    "preToolUse": [{ "type": "command", "bash": "bash scripts/block-dangerous.sh" }]
  }
}
```

Claude Code hook config (`.claude/settings.json`):
```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{ "type": "command", "command": "bash scripts/block-dangerous.sh" }]
    }]
  }
}
```

The script itself reads JSON from stdin and writes JSON to stdout in both tools. The **input** schema differs slightly (Copilot CLI uses `toolName`/`toolInput`, Claude Code uses `tool_name`/`tool_input`), so scripts that inspect the payload should handle both:

```bash
#!/usr/bin/env bash
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // .toolName')
```

## Plugin Compatibility

### Plugin manifests — two files, each tool reads its own

Both tools discover `.claude-plugin/plugin.json`, but their schemas differ enough to require separate content. Use two manifests:

| File | Read by | Contains |
|------|---------|---------|
| `.claude-plugin/plugin.json` | Claude Code (native) + Copilot CLI (priority 4) | `name`, `description`, `version`, `author`, `license`, `keywords` — nothing else |
| `plugin.json` (root) | Copilot CLI (priority 2, wins over priority 4) | All of the above + `agents`, `skills`, `hooks`, `_meta`, `mcpServers` |

Copilot CLI uses `plugin.json` (root, priority 2) when it exists. Claude Code only ever reads `.claude-plugin/plugin.json`.

**Why separate content?**
- Claude Code rejects `agents: "agents/"`, `skills: "skills/"`, `hooks: "hooks/hooks.json"` (string paths) — it auto-discovers these from standard directories
- Claude Code rejects unknown top-level keys like `_meta`
- Copilot CLI requires explicit `agents`/`skills`/`hooks` string paths to load plugin components

**Claude Code auto-discovery (from plugin root):**

| Component | Auto-discovered path |
|-----------|---------------------|
| Agents | `agents/*.agent.md` |
| Skills | `skills/*/SKILL.md` |
| Hooks | `hooks/hooks.json` |
| MCP | `.mcp.json` |

Paths in manifests resolve relative to the **plugin root** (the directory containing `.claude-plugin/`).

### Plugin hooks — two hook files, one set of scripts

Claude Code only accepts PascalCase event names in `hooks/hooks.json`. Copilot CLI only accepts camelCase. Split into two files referencing the same scripts:

| File | Read by | Events |
|------|---------|--------|
| `hooks/hooks.json` | Claude Code (auto-discovered) | PascalCase: `SessionStart`, `SessionEnd`, `PreToolUse`, `PostToolUse` |
| `hooks/hooks.copilot.json` | Copilot CLI (via root `plugin.json`) | camelCase: `sessionStart`, `sessionEnd`, `preToolUse`, `postToolUse` |

Root `plugin.json` references: `"hooks": "hooks/hooks.copilot.json"`.

Field name also differs: Claude Code uses `"command"`, Copilot CLI uses `"bash"`. Use `$CLAUDE_PLUGIN_ROOT` in both — set by both tools.

### Marketplace — `.claude-plugin/marketplace.json` is the DRY path

| Path | Copilot CLI | Claude Code |
|------|-------------|-------------|
| `marketplace.json` (root) | ✅ | ❌ |
| `.plugin/marketplace.json` | ✅ | ❌ |
| `.github/plugin/marketplace.json` | ✅ | ❌ |
| **`.claude-plugin/marketplace.json`** | **✅** | **✅** |

### Plugin install — marketplace is the only cross-tool method

| Method | Copilot CLI | Claude Code |
|--------|-------------|-------------|
| `OWNER/REPO` (direct) | ✅ | ❌ |
| `name@marketplace` | ✅ | ✅ |
| Local path | ✅ | ✅ (`--plugin-dir`) |

Create a marketplace repo, add it to both tools, then install by name:

```bash
copilot plugin marketplace add OWNER/marketplace-repo
claude plugin marketplace add OWNER/marketplace-repo

copilot plugin install my-plugin@marketplace-name
claude plugin install my-plugin@marketplace-name
```

### Plugin agent files: `.agent.md` extension

Use `.agent.md` for plugin agent files. Copilot CLI requires this extension. Claude Code accepts any `*.md` — `.agent.md` matches.

### Plugin hooks: dual-casing

Both event casings coexist in one `hooks.json`. Each tool reads its own casing:

```json
{
  "hooks": {
    "sessionEnd": [
      { "type": "command", "bash": "bash \"$CLAUDE_PLUGIN_ROOT/scripts/check.sh\"" }
    ],
    "SessionEnd": [
      { "hooks": [{ "type": "command", "command": "bash \"${CLAUDE_PLUGIN_ROOT}/scripts/check.sh\"" }] }
    ]
  }
}
```

Use `$CLAUDE_PLUGIN_ROOT` — set by both tools (Copilot CLI since v1.0.12).

### Dual-format plugin directory

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json               # Minimal — Claude Code reads this (name/description/version/author/license/keywords)
├── plugin.json                   # Full — Copilot CLI reads this (+ agents/skills/hooks/_meta)
├── skills/                       # Shared — both discover
│   └── my-skill/
│       └── SKILL.md
├── agents/
│   └── helper.agent.md           # .agent.md works in both tools
├── hooks/
│   ├── hooks.json                # PascalCase events — Claude Code auto-discovers
│   └── hooks.copilot.json        # camelCase events — Copilot CLI reads via root plugin.json
├── .mcp.json                     # Shared MCP config
└── scripts/                      # Shared hook scripts
    └── audit.sh
```

## Recommended Project Layout (DRY)

```
my-project/
├── AGENTS.md                     # Instructions — single source of truth
├── CLAUDE.md                     # Thin: @AGENTS.md + Claude-specific overrides
├── .mcp.json                     # MCP servers — fully shared
├── .claude/
│   ├── settings.json             # Shared settings (permissions, hooks for Claude Code)
│   ├── settings.local.json       # Personal overrides (gitignored)
│   ├── rules/                    # Claude Code path-scoped rules (Claude-only)
│   │   └── api-style.md
│   ├── skills/                   # Skills — discovered by both tools
│   │   ├── deploy/
│   │   │   └── SKILL.md
│   │   └── code-review/
│   │       └── SKILL.md
│   └── agents/                   # Agents — discovered by both tools
│       ├── reviewer.agent.md
│       └── db-analyst.agent.md
├── .github/
│   ├── hooks/                    # Copilot CLI hooks
│   │   └── hooks.json
│   ├── copilot-instructions.md   # Copilot-specific (optional, additive)
│   └── instructions/
│       └── api-routes.instructions.md
├── scripts/                      # Shared hook scripts
│   └── audit.sh
└── src/
    └── ...
```

## Gitignore Additions

```gitignore
.claude/settings.local.json
CLAUDE.local.md
.github/hooks/logs/
```
