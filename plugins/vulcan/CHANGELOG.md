## [0.19.5]

- doc(AGENTS.md): make marketplace update mandatory step; three-file rule; sibling-repo discovery
- doc(known-pitfalls): add marketplace-must-be-updated pitfall with three-file table and sibling-repo rule

## [0.19.4]

- fix(claude-plugin/version): sync `.claude-plugin/plugin.json` — this is the file `claude plugin update` reads

## [0.19.3]

- feat(skills/project-memory): prepend BLOCKING prefix to description — names the competing tools (Write/Edit) and echoes system instruction language to force skill invocation over direct file edits

## [0.19.2]

- fix(hooks/copilot): add version field and remove duplicate injection

# Changelog

- Fix dual-manifest schema: `.claude-plugin/plugin.json` is minimal (no agents/skills/hooks/_meta — Claude Code rejects them); root `plugin.json` is full Copilot CLI format (agents/skills/hooks/_meta); Copilot CLI reads root (priority 2), Claude Code reads .claude-plugin (only path it knows)
- Split hooks into `hooks/hooks.json` (PascalCase — Claude Code auto-discovers) and `hooks/hooks.copilot.json` (camelCase — Copilot CLI reads via root plugin.json); Claude Code rejects camelCase event names
- Update `dual-tool-setup.md` plugin section: two-manifest pattern, auto-discovery table, two hook files pattern
- Update `known-pitfalls.md`: correct manifest and hooks dual-tool pitfalls with split-file solutions
- Add dual-cased hooks: camelCase (Copilot CLI) + PascalCase (Claude Code) events coexist in `hooks/hooks.json`; use `$CLAUDE_PLUGIN_ROOT` which both tools set
- Update agent discovery: `.claude/agents/` is now DRY — Copilot CLI discovers it alongside Claude Code; `.agent.md` extension works in both tools
- Rewrite `dual-tool-setup.md` plugin section: single manifest path, marketplace as cross-tool install method, dual-cased hooks pattern, environment variable compatibility table
- Update `loading-precedence.md` agent table with Copilot CLI's expanded `.claude/agents/` discovery (user + project + inherited)
- Add `dual-tool-setup.md` resource: comprehensive DRY configuration guide for projects using both Copilot CLI and Claude Code — shared paths (`.claude/skills/`, `.mcp.json`, `AGENTS.md` + `CLAUDE.md` bridge), separate-but-DRY patterns (agents, hooks), recommended project layout, SKILL.md frontmatter compatibility matrix, plugin dual-format directory structure
- Rewrite `loading-precedence.md` with cross-tool comparison columns (Copilot CLI vs Claude Code) for agents, skills, instructions, and hooks; add Claude Code agent and rule discovery paths
- Change skills recommendation from `.agents/skills/` to `.claude/skills/` — the latter is explicitly documented and verified in both Copilot CLI and Claude Code; `.agents/skills/` "Portable" label is unconfirmed in Claude Code
- Add dual-tool pitfalls to `known-pitfalls.md`: `.agents/skills/` discovery uncertainty, `CLAUDE.md` bridge requirement, camelCase vs PascalCase hook events, divergent hook payload field names, incompatible plugin manifest paths, agent file path/extension differences
- Update `project-local-customization` skill with dual-tool project layout, Claude Code agent/hook/rule sections, and cross-references to `dual-tool-setup.md`
- Refresh Vulcan for Copilot CLI 1.0.27 (SDK stays at 0.2.2); v1.0.26: plugin hooks receive `PLUGIN_ROOT`/`COPILOT_PLUGIN_ROOT`/`CLAUDE_PLUGIN_ROOT` env vars pointing to plugin installation directory, `notification` hook only fires when permission prompt is actually shown, duplicate instruction file dedup reduces wasted tokens, context compaction checkpoint boundary fix, "steering" renamed to "remote control"; v1.0.27: `/ask` command for quick questions without affecting history, `copilot plugin marketplace update` to refresh catalogs
- Update `version-check.sh` to prefer `COPILOT_PLUGIN_ROOT` for plugin root resolution (v1.0.26 env vars)
- Add v1.0.26 hook pitfalls to `known-pitfalls.md`: `PLUGIN_ROOT` env vars, notification hook behavior change, instruction dedup, context compaction fix
- Refresh Vulcan for Copilot CLI 1.0.25 (SDK stays at 0.2.2); covers MCP registry installation with guided configuration, `/env` command for environment introspection, `--remote`/`/remote` for remote session control, ACP clients providing MCP servers (stdio/HTTP/SSE), MCP remote connection auto-retry on transient failures, skill instruction persistence fix across conversation turns, custom instruction special character preservation, `/share html` Ctrl+X O open support
- Fix: replace mechanical `sessionEnd` cascade hook with agent-driven parallel subagent cascade in `AGENTS.md` — dependent plugins in `$COPILOT_UPDATE_PLUGINS` are now updated by subagents with full CLI/SDK changelog awareness, not blind `jq` version stamps
- Add `modifiedArgs` redirect patterns and deny-vs-redirect decision matrix to `hook-lifecycle.md`: real-world `_redirect()` helper, domain-specific auto-fix examples, `postToolUse` + `modifiedResult` secret redaction pattern
- Add hook design pitfalls to `known-pitfalls.md`: deny-and-retry anti-pattern, `modifiedArgs` without `additionalContext` teaches nothing, `modifiedResult` is defense-in-depth (not replacement for `preToolUse`)
- Add `cli-extensions` skill: complete CLI extension system reference — `joinSession()` API, custom tool registration, extension hooks with full return value API, `session.on()` event listeners, `session.send()` programmatic prompts, self-healing loops, result redaction, architecture enforcement patterns
- Add `cli-flags-and-sessions.md` resource: CLI invocation modes (`-p`, `--autopilot`, `--output-format=json`), session management (`--continue`, `--resume`), remote access, ACP, all slash commands (`/fleet`, `/delegate`, `/pr`, `/extensions`, `/share html`), `@` file mentions, background agent features (`write_agent`, `subagentStart`, critic agent)
- Add hook return value API to `hook-lifecycle.md`: `additionalContext`, `permissionDecision`, `modifiedArgs`/`updatedInput`, `modifiedResult` (redaction), `errorHandling`/`retryCount`/`userNotification`; comparison table for file-based vs extension vs SDK hooks
- Add extension pitfalls to `known-pitfalls.md`: `onSessionStart` multi-fire, `session.send()` infinite loops, `skipPermission` bypasses all hooks, SDK auto-resolution (no `npm install`)
- Add extensions vs plugins distinction to `cli-plugin-reference` skill; add extensions loading section to `loading-precedence.md`
- Vulcan agent now covers 4 domains (was 3): project-local customization, CLI extensions, plugins, SDK apps; eagerly loads `cli-extensions` skill
- Refresh Vulcan for Copilot CLI 1.0.24 and SDK 0.2.2; CLI v1.0.23 adds `--mode`/`--autopilot`/`--plan` flags, `/diff`/`/agent` work while agent running; v1.0.24: `preToolUse` hooks now respect `modifiedArgs`/`updatedInput`/`additionalContext`, agent model field accepts display names and vendor suffixes; SDK v0.2.2: `sessionFs` now across all SDKs (was Node-only), `enableConfigDiscovery` for auto MCP/skill loading, model capabilities override in `setModel`
- Fix: replace auto-update/build-from-source MCP wrapper pattern with pre-compiled binary strategy in `cli-plugin-reference` skill — binaries must be committed to repo, wrapper reduced to platform detection only
- Fix: add `sessionStart` hook (`inject-memory.sh`) to detect project memory directories and inject context — ensures requirements go to `doc/requirements/` and pitfalls to `.agents/memory/`, never to session state; broaden `project-memory` skill trigger words to cover "requirement", "spec", "acceptance criteria", "component specification".
- Fix: document eager loading ≠ agent-private skills (count remains 24 = 1 built-in + personal + plugin; CLI has no agent-private registration); add release binary pitfall (binaries must be attached at release creation, not separately); tighten AGENTS.md release wording.
- Document compiled MCP server release and auto-update pattern in `cli-plugin-reference` skill; update `AGENTS.md` with release step and compiled-server procedure.
- Add `project-memory` skill: persistent agent memory pattern with known-pitfalls file, lessons-learned directory, feature requirements templates, and `sessionStart` hook injection.
- Leverage eager skill loading (v1.0.22): 6 SDK/plugin skills pre-loaded into Vulcan agent via `skills` frontmatter; `project-local-customization` stays plugin-level for cross-agent discoverability.
- Refresh Vulcan for Copilot CLI 1.0.22 (SDK stays at 0.2.1); **breaking:** `.vscode/mcp.json` and `.devcontainer/devcontainer.json` removed as MCP config sources — all MCP docs rewritten to use `.mcp.json`; covers eager skill loading via agent `skills` field, sub-agent depth/concurrency limits, `sessionStart`/`sessionEnd` firing once per session, plugin agents respecting frontmatter model, and plugin persistence across sessions.
- Refresh Vulcan for Copilot CLI 1.0.21 (SDK stays at 0.2.1); covers `copilot mcp` command, `/mcp enable`/`/mcp disable` persistence, PascalCase hook payload normalization, OpenTelemetry monitoring help topic, and `/yolo` persistence across `/restart`.
- Refresh Vulcan for Copilot CLI 1.0.18 and Copilot SDK 0.2.1, covering built-in skills, newer hook behavior, and SDK UI and session APIs.
- Clarify the AGENTS procedure so version refreshes also update the changelog with concise top-level bullets only.


