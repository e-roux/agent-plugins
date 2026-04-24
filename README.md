# agent-plugins

Mono-repo for agent plugins — works with **GitHub Copilot CLI**, **Claude Code**, and **pi coding agent**.

## Install

### Copilot CLI / Claude Code

```bash
copilot plugin marketplace add e-roux/agent-plugins
```

### Pi coding agent

```bash
pi install git:github.com/e-roux/agent-plugins
```

Or install individual plugins:

```bash
pi install git:github.com/e-roux/agent-plugins --skill plugins/dev/skills
```

## Plugins

| Plugin | Copilot CLI | Claude Code | Pi | Description |
|--------|:-----------:|:-----------:|:--:|-------------|
| `make` | ✅ | ✅ | ✅ | Make-first workflow enforcement |
| `dev` | ✅ | ✅ | ✅ | Development guards (secrets, comments, branches, migrations, CI pipeline) |
| `infra` | ✅ | ✅ | ✅ | Infrastructure & deployment guards (Ansible, Molecule) |
| `web-browser` | ✅ | ✅ | ✅ | CDP-based Chrome automation for web design verification |
| `vulcan` | ✅ | ✅ | — | Copilot CLI plugin development expert |

### Agent compatibility

All plugins use the [Agent Skills](https://agentskills.io) open standard (`SKILL.md`), which is portable across all three agents with zero modification.

Hooks and extensions are agent-specific:
- **Copilot CLI**: `hooks/*.copilot.json` + `.mjs` extensions
- **Claude Code**: `hooks/hooks.json` in `.claude-plugin/`
- **Pi**: TypeScript extensions in `extensions/pi/`

## Companion tools

| Tool | Description |
|------|-------------|
| [`mcp-git-ops`](https://github.com/e-roux/mcp-git-ops) | MCP server for platform-agnostic git operations — required by `dev` plugin (Copilot CLI / Claude Code only; pi uses extension tools) |
