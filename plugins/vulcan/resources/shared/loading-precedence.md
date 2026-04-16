# Loading Order & Precedence

Entries marked **portable** work across copilot-cli, Claude Code, Cursor, and other tools. Entries marked **GitHub** require the GitHub/Copilot ecosystem.

## Agents (first-found-wins)

Agents are deduplicated by ID (derived from filename minus `.agent.md`). The first match found wins — project-level cannot be overridden by plugins.

| Priority | Location | Scope | Copilot CLI | Claude Code |
|----------|----------|-------|-------------|-------------|
| 1 | `~/.copilot/agents/` | User global | ✅ | ❌ |
| 2 | `.github/agents/*.agent.md` | Project | ✅ | ❌ |
| 3 | `<parents>/.github/agents/` | Inherited (monorepo) | ✅ | ❌ |
| 4 | `~/.claude/agents/` | User global | ✅ | ✅ |
| 5 | **`.claude/agents/`** | **Project** | **✅** | **✅** |
| 6 | `<parents>/.claude/agents/` | Inherited (monorepo) | ✅ | ✅ |
| 7 | Plugin `agents/` dirs | Plugin (by install order) | ✅ | ✅ |
| 8 | Org/enterprise agents | Remote (via API) | ✅ | ❌ |

**`.claude/agents/` is now the DRY project-level agent path** — Copilot CLI discovers it (priority 5) alongside Claude Code (native). This is a recent addition to Copilot CLI's discovery order. Agent files should use the `.agent.md` extension (required by Copilot CLI, accepted by Claude Code since `*.agent.md` matches `*.md`).

For user-level agents, `~/.claude/agents/` is discovered by both tools (priority 4).

Sources: [custom-agents-configuration](https://docs.github.com/en/copilot/reference/custom-agents-configuration), [copilot-cli issue #452](https://github.com/github/copilot-cli/issues/452).

## Skills (first-found-wins)

Skills are deduplicated by `name` field. The first match found wins.

| Priority | Location | Scope | Copilot CLI | Claude Code |
|----------|----------|-------|-------------|-------------|
| 1 | `.github/skills/` | Project | ✅ | ❌ |
| 2 | `.agents/skills/` | Project | ✅ (Portable label) | ⚠️ Not explicitly documented |
| 3 | `.claude/skills/` | Project | ✅ | ✅ |
| 4 | `~/.copilot/skills/` | User global | ✅ | ❌ |
| 5 | `~/.agents/skills/` | User global (v1.0.11+) | ✅ (Portable label) | ⚠️ Not explicitly documented |
| 6 | `~/.claude/skills/` | User global | ✅ | ✅ |
| 7 | Plugin `skills/` dirs | Plugin (by install order) | ✅ | ✅ |
| 8 | `/skills add` + `COPILOT_SKILLS_DIRS` | Custom | ✅ | ❌ |

**Recommendation:** Use **`.claude/skills/`** for project-level skills when targeting both Copilot CLI and Claude Code — it is the only project-level path explicitly documented and verified in both tools. Use `~/.claude/skills/` for personal skills for the same reason.

> **Note on `.agents/skills/`:** Copilot CLI labels this path as "Portable" and claims compatibility with Claude Code, Cursor, and other tools via the [Agent Skills](https://agentskills.io) standard. However, Claude Code's documentation only lists `.claude/skills/` as a project skill discovery path. Until Claude Code explicitly documents `.agents/skills/`, prefer `.claude/skills/` for guaranteed cross-tool compatibility.

Sources: [creating agent skills](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/create-skills), [awesome-copilot issue #795](https://github.com/github/awesome-copilot/issues/795).

## MCP Servers (last-wins)

Later sources override earlier ones with the same server name.

| Priority | Location | Scope | Portability |
|----------|----------|-------|-------------|
| 1 (lowest) | `~/.copilot/mcp-config.json` | User global | GitHub |
| 2 | `.mcp.json` | Project | **Portable** |
| 3 | `.github/mcp.json` | Project | GitHub |
| 4 | Plugin MCP configs | Plugin | GitHub |
| 5 (highest) | `--additional-mcp-config` flag | CLI flag | GitHub |

> **⚠️ Breaking change (v1.0.22):** `.vscode/mcp.json` and `.devcontainer/devcontainer.json` are no longer read. Migrate to `.mcp.json` at the project root.

**Recommendation:** Use `.mcp.json` at the project root for project MCP — it is recognized by VS Code, copilot-cli, and other MCP-aware tools.

## Instructions

Multiple instruction sources are additive — they do not override each other.

| Location | Scope | Copilot CLI | Claude Code |
|----------|-------|-------------|-------------|
| `AGENTS.md` | Repo root + cwd | ✅ Native | ⚠️ Via `@AGENTS.md` import in `CLAUDE.md` |
| `CLAUDE.md` / `.claude/CLAUDE.md` | Repo root | ✅ Native | ✅ Native |
| `GEMINI.md` | Repo root | ✅ Native | ❌ |
| `.github/copilot-instructions.md` | Repo-wide | ✅ | ❌ |
| `.github/instructions/*.instructions.md` | Path-scoped (via `globs`) | ✅ | ❌ |
| `.claude/rules/*.md` | Path-scoped (via `globs` frontmatter) | ❌ | ✅ |
| `~/.copilot/copilot-instructions.md` | User global | ✅ | ❌ |
| `~/.claude/CLAUDE.md` | User global | ❌ | ✅ |

### Settings Files (v1.0.12+)

`.claude/settings.json` and `.claude/settings.local.json` are read as additional repo config sources by both tools. These provide a project-scoped way to configure settings (including hooks for Claude Code) alongside `.github/` convention files.

**Recommendation:** Write all project instructions in `AGENTS.md` (both tools can read it). For Claude Code, create a thin `CLAUDE.md` containing `@AGENTS.md` to import the shared instructions, plus any Claude-specific overrides. See `resources/shared/dual-tool-setup.md` for the full DRY pattern.

## Hooks

Hooks from multiple sources **merge** (v1.0.11+) — they no longer overwrite each other.

| Location | Scope | Copilot CLI | Claude Code |
|----------|-------|-------------|-------------|
| `.github/hooks/*.json` | Project (any `.json` file in dir) | ✅ | ❌ |
| `.claude/settings.json` hooks section | Project | ✅ (v1.0.12+) | ✅ |
| `.claude/settings.local.json` hooks section | Project (personal) | ✅ (v1.0.12+) | ✅ |
| `settings.json`, `settings.local.json` | Project | ✅ | ❌ |
| `~/.copilot/config.json` (hooks section) | User global | ✅ | ❌ |
| `~/.claude/settings.json` hooks section | User global | ❌ | ✅ |
| Plugin `hooks.json` (via `plugin.json` `hooks` field) | Plugin | ✅ | ✅ |

> **Monorepo (v1.0.11+):** Hooks discovered at every directory from CWD up to git root.
> **`-p` mode (v1.0.11):** `.github/hooks/` is *discovered* in `-p` mode but hooks do **not execute**. Use interactive mode to validate hook behaviour.

Hook **configuration formats differ** between the two tools (camelCase vs PascalCase events, different matcher syntax). However, hook **scripts** can be shared — keep reusable scripts in `scripts/` and reference them from both tool-specific configs. See `resources/shared/dual-tool-setup.md` for the dual-wiring pattern.

## Extensions

Extensions are loaded from `.github/extensions/<name>/extension.mjs`. They run as forked child processes and are not part of the plugin/skill loading hierarchy — they operate in parallel.

| Location | Scope | Portability |
|----------|-------|-------------|
| `.github/extensions/<name>/extension.mjs` | Project | GitHub |

Extensions are reloaded via `extensions_reload` or `/clear`. They are not affected by agent/skill/MCP precedence — their tools and hooks merge additively with all other sources.

## Built-in Components

Built-in tools (`bash`, `view`, `edit`, `glob`, `rg`, `task`, ...) and CLI-provided agents (for example `explore`, `task`, and `general-purpose`) are always present and cannot be overridden. Since CLI v1.0.17, the CLI also ships built-in skills (starting with cloud-agent environment customization guidance), so treat those as always-available references alongside the custom skill discovery layers above.
