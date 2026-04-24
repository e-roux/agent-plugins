# agent-plugins

Marketplace for e-roux agent plugins — works with both GitHub Copilot CLI and Claude Code.

## Usage

```bash
copilot plugin marketplace add e-roux/agent-plugins
```

## Architecture

Each plugin directory under `plugins/` contains the full plugin source
(no git submodules). This ensures `copilot plugin install` gets all files
via a shallow clone.

## Updating plugins

When plugin source repos are updated, sync the latest content:

```bash
make sync     # copies from local plugin repos into plugins/
make verify   # checks all plugins have plugin.json
git add -A && git commit -m "chore: sync plugins"
git push
```

## Plugins

| Plugin | Description |
|--------|-------------|
| `make` | Make-first workflow enforcement |
| `dev` | Development guards (secrets, comments, branches, migrations, MCP git-ops) |
| `vulcan` | Copilot CLI plugin development expert |
| `infra` | Infrastructure & deployment guards |

## Companion tools

| Tool | Description |
|------|-------------|
| [`mcp-git-ops`](https://github.com/e-roux/mcp-git-ops) | MCP server for platform-agnostic git operations (push, PR, merge) — required by the `dev` plugin for full git-ops tooling |

Install `mcp-git-ops`:
```bash
go install github.com/e-roux/mcp-git-ops@latest
```
