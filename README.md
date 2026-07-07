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
```

### Pi coding agent

```bash
pi install git:github.com/e-roux/agent-plugins
```

## Plugins

| Plugin | Copilot CLI | Claude Code | Gemini CLI | Pi | Description |
|--------|:-----------:|:-----------:|:----------:|:--:|-------------|
| `make` | ✅ | ✅ | ✅ | ✅ | Make-first workflow enforcement |
| `dev` | ✅ | ✅ | ✅ | ✅ | Development guards (secrets, comments, branches, migrations, CI pipeline) |
| `infra` | ✅ | ✅ | ✅ | ✅ | Infrastructure & deployment guards (Ansible, Molecule) |
| `vulcan` | ✅ | ✅ | ✅ | — | Copilot CLI plugin development expert |

### Agent compatibility

Hooks, extensions, and manifests are agent-specific:
- **Copilot CLI**: `plugin.json` manifest + `hooks/*.copilot.json` + `.mjs` extensions
- **Claude Code**: `.claude-plugin/plugin.json` manifest + `hooks/hooks.copilot.json` (Claude Code event names: `preToolUse`/`postToolUse`/`userPromptSubmit`)
- **Gemini CLI**: `gemini-extension.json` manifest + `GEMINI.md` context + `hooks/hooks.json` (Gemini event names: `BeforeTool`/`AfterTool`/`BeforeAgent`)
- **Pi**: `package.json` manifest + TypeScript extensions in `extensions/pi/`

## Skills

Skill content (`SKILL.md` + resources) for these plugins lives in a separate,
agent-agnostic repository — [`e-roux/agent-skills`](https://github.com/e-roux/agent-skills) —
following the [Agent Skills](https://agentskills.io) open standard. Install it independently
of the plugins here:

```bash
skills add e-roux/agent-skills
```

`vulcan` is the one exception: its skills document how to build plugins in *this* repo, so
they stay bundled locally under `plugins/vulcan/skills/`.

## Companion tools

| Tool | Description |
|------|-------------|
| [`mcp-git-ops`](https://github.com/e-roux/mcp-git-ops) | MCP server for platform-agnostic git operations — required by `dev` plugin (Copilot CLI / Claude Code only; pi uses extension tools) |
