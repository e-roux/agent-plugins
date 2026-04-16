---
name: cli-plugin-reference
description: >
  Reference for building and distributing GitHub Copilot CLI plugins. Use when the user wants to
  create a plugin, scaffold plugin.json, structure agents and skills in a plugin, publish to a
  marketplace, install or manage plugins, or debug plugin loading issues — even if they just say
  "make a copilot plugin" or "package this as a plugin".
---

# Copilot CLI Plugin Reference

## Plugin Structure

A plugin is a directory containing a `plugin.json` manifest and optional component directories.
The manifest may be placed at `.claude-plugin/plugin.json` (recommended — DRY path for both Copilot CLI and Claude Code), `plugin.json` (root), `.plugin/plugin.json`, or `.github/plugin/plugin.json`.

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json           # Required manifest (DRY — both tools discover)
├── agents/               # Custom agents (.agent.md files)
│   └── helper.agent.md
├── skills/               # Skills (SKILL.md in subdirectories)
│   └── deploy/
│       └── SKILL.md
├── hooks.json            # Hook configuration
└── .mcp.json             # MCP server config
```

## plugin.json Manifest

### Required Field

| Field  | Type   | Description                                                            |
|--------|--------|------------------------------------------------------------------------|
| `name` | string | Kebab-case plugin name (letters, numbers, hyphens only). Max 64 chars. |

### Optional Metadata Fields

| Field         | Type      | Description                              |
|---------------|-----------|------------------------------------------|
| `description` | string    | Brief description. Max 1024 chars.       |
| `version`     | string    | Semantic version (e.g., `1.0.0`).        |
| `author`      | object    | `name` (required), `email`, `url`.       |
| `homepage`    | string    | Plugin homepage URL.                     |
| `repository`  | string    | Source repository URL.                   |
| `license`     | string    | License identifier (e.g., `MIT`).        |
| `keywords`    | string[]  | Search keywords.                         |
| `category`    | string    | Plugin category.                         |
| `tags`        | string[]  | Additional tags.                         |

### Component Path Fields

| Field        | Type                | Default   | Description                                              |
|--------------|---------------------|-----------|----------------------------------------------------------|
| `agents`     | string \| string[]  | `agents/` | Path(s) to agent directories (`.agent.md` files).        |
| `skills`     | string \| string[]  | `skills/` | Path(s) to skill directories (`SKILL.md` files).         |
| `commands`   | string \| string[]  | —         | Path(s) to command directories.                          |
| `hooks`      | string \| object    | —         | Path to hooks config file, or inline hooks object.       |
| `mcpServers` | string \| object    | —         | Path to MCP config file, or inline server definitions.   |
| `lspServers` | string \| object    | —         | Path to LSP config file, or inline server definitions.   |

### Example plugin.json

```json
{
  "name": "my-dev-tools",
  "description": "React development utilities",
  "version": "1.2.0",
  "author": { "name": "Jane Doe", "email": "jane@example.com" },
  "license": "MIT",
  "keywords": ["react", "frontend"],
  "agents": "agents/",
  "skills": ["skills/", "extra-skills/"],
  "hooks": "hooks.json",
  "mcpServers": ".mcp.json"
}
```

## Agent & Skill Files

For the `.agent.md` format, see `resources/shared/agent-md-format.md`.
For the `SKILL.md` format, see `resources/shared/skill-md-format.md`.

Since CLI v1.0.17, the CLI also ships built-in skills. Before adding a plugin skill, check
`/skills list` so you do not duplicate a skill users already have by default.

## Plugin CLI Commands

| Command                                        | Description                        |
|------------------------------------------------|------------------------------------|
| `copilot plugin install SPECIFICATION`         | Install a plugin                   |
| `copilot plugin uninstall NAME`                | Remove a plugin                    |
| `copilot plugin list`                          | List installed plugins             |
| `copilot plugin update NAME`                   | Update a plugin                    |
| `copilot plugin update --all`                  | Update all installed plugins       |
| `copilot plugin disable NAME`                  | Temporarily disable a plugin       |
| `copilot plugin enable NAME`                   | Re-enable a disabled plugin        |
| `copilot mcp`                                  | Interactive MCP server management (v1.0.21+) |

### Install Specification Formats

| Format         | Example                      | Description                    |
|----------------|------------------------------|--------------------------------|
| Marketplace    | `plugin@marketplace`         | From a registered marketplace  |
| GitHub         | `OWNER/REPO`                 | Root of a GitHub repository    |
| GitHub subdir  | `OWNER/REPO:PATH/TO/PLUGIN`  | Subdirectory in a repo         |
| Git URL        | `https://github.com/o/r.git` | Any Git URL                    |
| Local path     | `./my-plugin` or `/abs/path` | Local directory                |

## Marketplace & Distribution

### awesome-copilot (Default Marketplace)

[github/awesome-copilot](https://github.com/github/awesome-copilot) is the default marketplace — it is pre-registered in Copilot CLI and VS Code. Install plugins from it directly:

```bash
copilot plugin install <plugin-name>@awesome-copilot
```

Browse available plugins in a session:

```
/plugin marketplace browse awesome-copilot
```

To publish your plugin to awesome-copilot, submit a PR to the `staged` branch of `github/awesome-copilot` following their [CONTRIBUTING.md](https://github.com/github/awesome-copilot/blob/main/CONTRIBUTING.md). The repo also has 200+ community agents, 270+ skills, and hooks — useful as real-world examples when building your own.

### Custom Marketplace (marketplace.json)

Create `marketplace.json` in `.github/plugin/` directory of a repository for a private or team marketplace.

```json
{
  "name": "my-marketplace",
  "owner": { "name": "Your Organization", "email": "plugins@example.com" },
  "metadata": { "description": "Curated plugins for our team", "version": "1.0.0" },
  "plugins": [
    {
      "name": "frontend-design",
      "description": "Create a professional-looking GUI",
      "version": "2.1.0",
      "source": "./plugins/frontend-design"
    }
  ]
}
```

### Marketplace Commands

| Command                                          | Description              |
|--------------------------------------------------|--------------------------|
| `copilot plugin marketplace add SPECIFICATION`   | Register a marketplace   |
| `copilot plugin marketplace list`                | List marketplaces        |
| `copilot plugin marketplace browse NAME`         | Browse plugins           |
| `copilot plugin marketplace update`              | Refresh plugin catalogs (v1.0.27) |
| `copilot plugin marketplace remove NAME`         | Unregister marketplace   |

## Compiled MCP Server Release

Plugins with compiled (Go) MCP servers MUST ship pre-compiled binaries directly in the repository.
This is the ONLY reliable approach — build-from-source and auto-update strategies are fragile and
have proven to fail in production (missing Go, network issues, CWD problems).

### Strategy: Pre-compiled binaries in repo

1. Cross-compile for all 4 platforms during development (`make mcp.build`)
2. Commit the binaries to `bin/` (un-gitignore them)
3. The wrapper script detects the platform and execs the correct binary — nothing else
4. On release, `make publish` rebuilds, commits, and creates a GitHub Release with binaries attached

### Makefile targets

```makefile
PLATFORMS := darwin/arm64 darwin/amd64 linux/amd64 linux/arm64
BINARY    := mcp-server
VERSION   := $(shell jq -r .version plugin.json)
REPO      := OWNER/REPO

mcp.build:
	for platform in $(PLATFORMS); do \
	  os=$${platform%%/*}; arch=$${platform##*/}; \
	  GOOS=$$os GOARCH=$$arch go build -ldflags="-s -w" \
	    -o $(BIN_DIR)/$(BINARY)-$$os-$$arch ./cmd/mcp-server; \
	done

publish: version.check mcp.build
	gh release create "v$(VERSION)" $(BIN_DIR)/$(BINARY)-* \
	  --title "v$(VERSION)" --notes-file CHANGELOG.md --latest
```

For plugins on GitHub Enterprise, prefix with `GH_HOST`:

```makefile
	GH_HOST=github.example.com gh release create ...
```

### Wrapper Script (bin/<name>.sh)

The wrapper is the command referenced by `plugin.json`. It does ONE thing: detect platform and exec.

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

os=$(uname -s | tr '[:upper:]' '[:lower:]')
arch=$(uname -m)
[[ "$arch" == "x86_64" ]] && arch="amd64"
[[ "$arch" == "aarch64" ]] && arch="arm64"

BINARY="$SCRIPT_DIR/<name>-${os}-${arch}"

if [[ ! -x "$BINARY" ]]; then
  printf "<name>: no binary for %s/%s at %s\n" "$os" "$arch" "$BINARY" >&2
  exit 1
fi

exec "$BINARY" "$@"
```

> **IMPORTANT**: Do NOT add build-from-source fallback, auto-update, version checking, or network
> calls to the wrapper. These are proven failure points. The binary must be in the repo.

### plugin.json MCP Configuration

Point the MCP server command at the wrapper script:

```json
{
  "mcpServers": {
    "my-server": {
      "command": "bash",
      "args": ["-c", "exec \"$HOME/.copilot/installed-plugins/_direct/my-plugin/bin/<name>.sh\""]
    }
  }
}
```

### Integration with Version Bump Procedure

The `AGENTS.md` recipe for compiled-MCP plugins adds a `make release` step after version bump and
changelog update. This ensures every plugin version has matching release binaries. The wrapper
auto-detects the new version within an hour of release.

## Extensions vs Plugins

Extensions and plugins are complementary but serve different purposes:

| Aspect | Plugins | Extensions |
|--------|---------|-----------|
| **Distribution** | Installable via `copilot plugin install` | Project-local only (`.github/extensions/`) |
| **Format** | `plugin.json` + agents/skills/hooks/MCP | Single `.mjs` file using `joinSession()` |
| **Custom tools** | Via MCP servers (separate process) | Inline JavaScript tool handlers |
| **Hooks** | File-based shell scripts (`hooks.json`) | Programmatic (full SDK access, event listeners) |
| **Event streaming** | ❌ | ✅ `session.on()` for real-time events |
| **Programmatic prompts** | ❌ | ✅ `session.send()` for injecting prompts |
| **Best for** | Reusable, team-wide knowledge and automation | Project-specific programmatic control |

**When a user needs both:** A plugin provides the knowledge layer (agents, skills, reference docs), while extensions provide the automation layer (custom tools, event-driven workflows, CI integration). They work together seamlessly.

For full extension documentation, see the `cli-extensions` skill.

## File Locations

| Item                 | Path                                                              |
|----------------------|-------------------------------------------------------------------|
| Installed plugins    | `~/.copilot/state/installed-plugins/`                             |
| Marketplace cache    | `~/.copilot/state/marketplace-cache/`                             |
| Plugin manifest      | `.claude-plugin/plugin.json` (DRY), `plugin.json`, `.plugin/plugin.json`, `.github/plugin/plugin.json` |
| Marketplace manifest | `.claude-plugin/marketplace.json` (DRY), `marketplace.json`, `.plugin/marketplace.json`, `.github/plugin/marketplace.json` |
| Hooks config         | `hooks.json` or `hooks/hooks.json`                                |
| LSP config           | `lsp.json` or `.github/lsp.json`                                  |

## Loading Order & Precedence

For the full loading order (agents, skills, MCP), see `resources/shared/loading-precedence.md`.
For MCP config file locations, see `resources/shared/mcp-config-locations.md`.

## Testing a Plugin Locally

```bash
# Install from local path
copilot plugin install ./my-plugin

# Verify it loaded
copilot plugin list

# In interactive session, check agents and skills
/agent
/skills list

# After changes, reinstall to pick up updates
copilot plugin install ./my-plugin

# Uninstall when done testing
copilot plugin uninstall my-plugin
```

## Plugin Hooks (v1.0.12+)

Plugin hooks declared via the `hooks` field in `plugin.json` gain additional capabilities in
v1.0.12. Newer CLI releases also add `permissionRequest` hooks (v1.0.16) and asynchronous
`notification` hooks (v1.0.18) alongside the core lifecycle events.

### Template Variables

Hook configurations support runtime-resolved template variables:

| Variable              | Resolved to                                     |
|-----------------------|-------------------------------------------------|
| `{{project_dir}}`     | The user's project root directory               |
| `{{plugin_data_dir}}` | Persistent data directory for this plugin       |

### Environment Variables

Plugin hook scripts receive:
- `CLAUDE_PROJECT_DIR` — same as `{{project_dir}}`
- `CLAUDE_PLUGIN_DATA` — same as `{{plugin_data_dir}}`
- `PLUGIN_ROOT` — the plugin's installation directory (v1.0.26+)
- `COPILOT_PLUGIN_ROOT` — same as `PLUGIN_ROOT` (v1.0.26+)
- `CLAUDE_PLUGIN_ROOT` — same as `PLUGIN_ROOT` (v1.0.26+)

These are **only** set for plugin hooks — project-local hooks do not receive them. For details, see `resources/shared/hook-lifecycle.md`.

If your plugin uses `preToolUse`, remember that on CLI v1.0.18+ returning
`{ "permissionDecision": "allow" }` skips the approval prompt entirely.

### Hook Payload Normalization (v1.0.21+)

Hooks configured with PascalCase event names now receive VS Code-compatible snake_case payloads
containing `hook_event_name`, `session_id`, and ISO 8601 timestamps. This ensures consistency
between copilot-cli and VS Code extension hook consumers.
