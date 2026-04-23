# Feature: Plugin update triggers marketplace update

## Context

When a plugin is released (version bump, content change, or any PR merged to main),
the marketplace repository must be updated atomically in the same release cycle.

Both Copilot CLI and Claude Code resolve plugin versions from the marketplace — neither
tool reads the plugin's own repository directly during `plugin update`. If the marketplace
is not updated, users will always see "already at the latest version" regardless of what
the plugin repo contains.

The marketplace is **user-specific**: a private sibling repository in the same owner
namespace, not a public registry or community awesome-list. It is located by scanning
the parent directory of the plugin repo for a repo containing `.claude-plugin/marketplace.json`.

## Acceptance Criteria

- [ ] AC-001: Every plugin release PR includes a corresponding marketplace PR updating all three version files atomically.
- [ ] AC-002: `.claude-plugin/marketplace.json` plugin `version` field matches the released plugin version.
- [ ] AC-003: `plugins/<name>/.claude-plugin/plugin.json` `version` field matches the released plugin version.
- [ ] AC-004: `plugins/<name>/plugin.json` `version` field matches the released plugin version.
- [ ] AC-005: The marketplace repo is located by scanning sibling directories — never hardcoded by name.
- [ ] AC-006: The marketplace PR is squash-merged and the branch deleted before the GitHub release is created.
- [ ] AC-007: The marketplace branch MUST be named `chore/<plugin-name>-v<version>` (e.g. `chore/vulcan-v0.19.7`).
- [ ] AC-008: After the marketplace PR is merged, a git tag `<plugin-name>/v<version>` is pushed to the marketplace repo (e.g. `vulcan/v0.19.7`), marking the exact marketplace state for that plugin release.

## Constraints

- Both Copilot CLI (`copilot plugin update`) and Claude Code (`claude plugin update`) read the marketplace for version resolution — docs must not attribute this to one tool only.
- The three marketplace files must be bumped in a single commit/PR, never separately.
- The marketplace is user-specific and private — never assume it is a public index.

## Non-Goals

- Publishing to any public plugin registry or awesome-list.
- Automating marketplace discovery beyond scanning the parent directory for `.claude-plugin/marketplace.json`.
