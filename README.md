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
| `dev` | ✅ | ✅ | ✅ | ✅ | General-purpose command center (Makefile targets, git, python, shell, and testing) |
| `infra` | ✅ | ✅ | ✅ | ✅ | Infrastructure & deployment guards (Ansible, Molecule) |
| `vulcan` | ✅ | ✅ | ✅ | — | Copilot CLI plugin development expert |

### Agent compatibility

Hooks, extensions, and manifests are agent-specific:
- **Copilot CLI**: `plugin.json` manifest + `hooks/*.copilot.json` + `.mjs` extensions
- **Claude Code**: `.claude-plugin/plugin.json` manifest with inline hook configurations
- **Gemini CLI**: `gemini-extension.json` manifest + `GEMINI.md` context + isolated `hooks/gemini.json` configuration
- **Pi**: `package.json` manifest + TypeScript extensions in `extensions/pi/`

## Skills

Skills are fully self-contained and bundled directly inside each respective plugin package to enforce maximum isolation and offline capability:

- **`dev` Plugin Skills** (`plugins/dev/skills/`):
  - `git`: Enforces branch-first development, quality gating, and commit message scopes.
  - `makefile`: Enforces `.SILENT`, `.ONESHELL`, explicit help banners, and make-only target execution.
  - `python`: Python tooling conventions (using `uv`, `ruff`, and `mypy`).
  - `shell`: Shell script guidelines and `shellcheck` robustness.
  - `testing`: Local unit testing and test-assessment paradigms.

- **`infra` Plugin Skills** (`plugins/infra/skills/`):
  - `ansible`: Best practices for writing Ansible roles, Molecule test pipelines, and inventory structures.

- **`vulcan` Plugin Skills** (`plugins/vulcan/skills/`):
  - Bundles skills for Copilot CLI TypeScript SDK development and shell extension customization.

All other general-purpose or platform-agnostic development skills live in the [`e-roux/agent-skills`](https://github.com/e-roux/agent-skills) repository.

## Companion tools

| Tool | Description |
|------|-------------|
| [`mcp-git-ops`](https://github.com/e-roux/mcp-git-ops) | MCP server for platform-agnostic git operations — required by `dev` plugin (Copilot CLI / Claude Code only; pi uses extension tools) |
