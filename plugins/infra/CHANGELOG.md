# Changelog

## [0.1.7]

- Split dual-manifest schema: root `plugin.json` for Copilot CLI (full format with `_meta`, `hooks`, `skills`), `.claude-plugin/plugin.json` for Claude Code (minimal: name, description, version, author, license, keywords only)
- Split hooks: `hooks/hooks.copilot.json` (camelCase for Copilot CLI), `hooks/hooks.json` (PascalCase only for Claude Code auto-discovery)

## [0.1.6]

- Move plugin manifest to `.claude-plugin/plugin.json` — DRY path for both Copilot CLI and Claude Code
- Add dual-cased hooks: PascalCase events for Claude Code alongside camelCase for Copilot CLI
- Use `$CLAUDE_PLUGIN_ROOT` (set by both tools) instead of `$COPILOT_PLUGIN_ROOT`

## [0.1.5]

- Align with Vulcan v0.18.0 dual-tool DRY guidance (no plugin-side changes needed — this plugin has no portable skill-path references)
- Bump patch version for metadata alignment

## [0.1.4]

- Bump Copilot CLI to 1.0.27 (SDK unchanged at 0.2.2)
- Hook scripts now use `$COPILOT_PLUGIN_ROOT` env var for path resolution instead of relative paths (CLI 1.0.26 provides `PLUGIN_ROOT`, `COPILOT_PLUGIN_ROOT`, `CLAUDE_PLUGIN_ROOT` to all hook commands)
- Add `copilot plugin marketplace update` command to README (CLI 1.0.27)

## [0.1.3]

- Bump Copilot CLI to 1.0.25; add `copilotSdkVersion` metadata field
- Skill instructions now persist correctly across conversation turns (CLI fix); no plugin-side change needed — ansible-molecule multi-turn guidance benefits automatically
- Add `/env` verification hint to README for confirming plugin load status
- Special characters in skill instructions are now preserved by the CLI (CLI fix); no plugin-side change needed

## [0.1.2]

- Add `sessionStart` and `preToolUse` hooks: inject Ansible/Molecule workflow guidance, block `ansible-playbook` without `--check` on non-local connections, redirect `ansible-lint` and `molecule` to make targets via `modifiedArgs` (CLI v1.0.24)

## [0.1.1]

- Bump Copilot CLI version to 1.0.24; no content changes

## [0.1.0]

- Initial release: `ansible-molecule` skill migrated from user-level to plugin for versioning and distribution
- Covers Ansible role and collection development with Molecule/Podman, ansible-lint, yamllint, and Make-centric workflow
