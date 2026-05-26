# agent-plugins

Mono-repo for agent plugins — works with **GitHub Copilot CLI**, **Claude Code**, **Gemini CLI**, and **pi coding agent**.

## Install

### Copilot CLI / Claude Code

```bash
copilot plugin marketplace add e-roux/agent-plugins
```

### Gemini CLI

Install individual plugins by pointing to their directory:

```bash
gemini extensions install https://github.com/e-roux/agent-plugins/plugins/dev
gemini extensions install https://github.com/e-roux/agent-plugins/plugins/make
gemini extensions install https://github.com/e-roux/agent-plugins/plugins/infra
gemini extensions install https://github.com/e-roux/agent-plugins/plugins/vulcan
gemini extensions install https://github.com/e-roux/agent-plugins/plugins/web-browser
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

| Plugin | Copilot CLI | Claude Code | Gemini CLI | Pi | Description |
|--------|:-----------:|:-----------:|:----------:|:--:|-------------|
| `make` | ✅ | ✅ | ✅ | ✅ | Make-first workflow enforcement |
| `dev` | ✅ | ✅ | ✅ | ✅ | Development guards (secrets, comments, branches, migrations, CI pipeline) |
| `infra` | ✅ | ✅ | ✅ | ✅ | Infrastructure & deployment guards (Ansible, Molecule) |
| `web-browser` | ✅ | ✅ | ✅ | ✅ | CDP-based Chrome automation for web design verification |
| `vulcan` | ✅ | ✅ | ✅ | — | Copilot CLI plugin development expert |

### Agent compatibility

All plugins use the [Agent Skills](https://agentskills.io) open standard (`SKILL.md`), which is portable across all agents with zero modification.

Hooks, extensions, and manifests are agent-specific:
- **Copilot CLI**: `plugin.json` manifest + `hooks/*.copilot.json` + `.mjs` extensions
- **Claude Code**: `.claude-plugin/plugin.json` manifest + `hooks/hooks.copilot.json` (Claude Code event names: `preToolUse`/`postToolUse`/`userPromptSubmit`)
- **Gemini CLI**: `gemini-extension.json` manifest + `GEMINI.md` context + `hooks/hooks.json` (Gemini event names: `BeforeTool`/`AfterTool`/`BeforeAgent`)
- **Pi**: `package.json` manifest + TypeScript extensions in `extensions/pi/`

## Companion tools

| Tool | Description |
|------|-------------|
| [`mcp-git-ops`](https://github.com/e-roux/mcp-git-ops) | MCP server for platform-agnostic git operations — required by `dev` plugin (Copilot CLI / Claude Code only; pi uses extension tools) |
