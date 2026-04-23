# Instructions
To get to know what is Vulcan, please read the README.md.
## MANDATORY Agent procedure
- Check the latest **stable** [copilot-cli release] and the [copilot-cli changelog].
- Check the latest **stable** [copilot-sdk release] and the [copilot-sdk changelog].
- if new versions are available, create a new branch in this repository
- Update and fill the information gap within agents, hooks, resources and skills definition
- Analyse the README.md for correctness with the newly updated information
- always bump the version (major/minor/patch) in **both** `plugin.json` AND `.claude-plugin/plugin.json` (the latter is what `claude plugin update` reads); for patches not implied by the `copilot-cli` or `copilot-sdk`, this is a patch update.
- update the changelog with top level bullets ONLY
- pr and merge to main
- **marketplace update** (MANDATORY): find the sibling marketplace repository (a separate repo in the same owner namespace, containing `.claude-plugin/marketplace.json`). Update **three files** atomically in one PR:
  1. `.claude-plugin/marketplace.json` — bump the plugin's `version` field (this is what `claude plugin update` resolves against)
  2. `plugins/<name>/.claude-plugin/plugin.json` — bump `version` (Claude Code reads this)
  3. `plugins/<name>/plugin.json` — bump `version` (Copilot CLI reads this)
  The marketplace is **user-specific** — it is not a public registry or awesome-list. Locate it by scanning sibling directories (same parent as the plugin repo) for a repo containing `.claude-plugin/marketplace.json`.
- **release**: create a GitHub release (`gh release create`) tagged with the new version; use the changelog diff as release notes
- switch back to main, clean branches in the repo

## Cascade Update to Dependent Plugins

After completing the vulcan release (when `_meta.copilotCliVersion` or
`_meta.copilotSdkVersion` changed), cascade the update to every plugin
listed in `$COPILOT_UPDATE_PLUGINS` (colon-separated local repo paths).

For each plugin, launch a **parallel subagent** (`task` tool,
`agent_type: "general-purpose"`, `mode: "background"`).

Provide each subagent with:
- the new CLI and SDK version numbers
- the relevant changelog excerpts from [copilot-cli changelog] and [copilot-sdk changelog]
- the absolute path to the dependent plugin repository

Each subagent MUST:
1. `cd` into the plugin repo, `git checkout main && git pull --ff-only`
2. Read the plugin's `plugin.json`, `AGENTS.md`, agents, skills, resources, and hooks
3. Update `_meta.copilotCliVersion`, `_meta.copilotSdkVersion`, `_meta.lastVerified`
4. Analyse each version-specific change from the changelogs and update
   agents, skills, resources, and hook definitions where the change has
   implications for that plugin
5. Bump the plugin version (patch unless the change is breaking)
6. Update the plugin's changelog with top-level bullets
7. Create branch `chore/cli-<version>-sdk-<version>`, commit, push,
   create PR via `gh pr create`, squash-merge via `gh pr merge --squash --delete-branch`
8. Return to clean `main`

Do NOT mechanically bump only metadata — each dependent plugin must be
updated with full awareness of what changed in the CLI/SDK.

## Compiled MCP Server Release Procedure
For plugins with compiled (Go) MCP servers, the version bump MUST also:
- run `make release` to cross-compile binaries and attach them to a GitHub release **in a single step** (binaries must be attached at creation time — not separately after)
- the `release` target builds for darwin/arm64, darwin/amd64, linux/amd64, linux/arm64
- the auto-update wrapper script (`bin/<name>.sh`) fetches the latest release binary on startup (throttled to once per hour)
- see the `cli-plugin-reference` skill for the full pattern

## Resources
[copilot-cli changelog]: https://github.com/github/copilot-cli/blob/main/changelog.md
[copilot-cli release]: https://github.com/github/copilot-cli/releases

[copilot-sdk changelog]: https://github.com/github/copilot-sdk/blob/main/CHANGELOG.md
[copilot-sdk release]: https://github.com/github/copilot-sdk/releases
