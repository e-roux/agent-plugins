# agent-plugins — Agent Instructions

Mono-repo of agent plugins for **GitHub Copilot CLI**, **Claude Code**, **Gemini CLI**, and **pi** coding agent.

## Repository layout

```
agent-plugins/
├── plugins/
│   ├── dev/           # development guards (secrets, comments, branches, migrations, CI)
│   ├── infra/         # infrastructure & deployment guards (Ansible, Molecule)
│   ├── make/          # Makefile-first workflow enforcement
│   └── vulcan/        # Copilot CLI plugin-development expert
├── .claude-plugin/
│   └── marketplace.json   # version registry consumed by `copilot plugin update` and `claude plugin update`
├── Makefile               # top-level QA: fmt / lint / typecheck / test / qa
└── CHANGELOG.md
```

Each plugin directory contains:
- `plugin.json` — Copilot CLI / Claude Code manifest; carries `_meta.copilotCliVersion` and `_meta.copilotSdkVersion`
- `gemini-extension.json` — Gemini CLI manifest; version must match `plugin.json`
- `GEMINI.md` — Gemini CLI context file (standalone behavioral instructions loaded at session start)
- `package.json` — Pi manifest (plugins that support pi only); carries a `"pi"` key
- `AGENTS.md` (when present) — plugin-specific agent instructions (supersede these root instructions for that plugin)

Skill content (`SKILL.md` + resources) for `dev`, `infra`, and `make` lives in the sibling
[`e-roux/agent-skills`](https://github.com/e-roux/agent-skills) repo, not under `plugins/*/skills/`
in this repo — install it separately with `skills add e-roux/agent-skills`. `vulcan` is the
exception: its skills describe how to build plugins *in this repo*, so they stay local under
`plugins/vulcan/skills/`. The `mcp-git-ops` MCP server used by `dev` similarly lives in its own
repo, [`e-roux/mcp-git-ops`](https://github.com/e-roux/mcp-git-ops) — installed via
`go install github.com/e-roux/mcp-git-ops@latest`, not vendored here.

## Agent version tracking

Copilot CLI and SDK versions currently in use are recorded **per plugin** inside `plugin.json`:

```json
"_meta": {
  "copilotCliVersion": "1.0.27",
  "copilotSdkVersion": "0.2.2",
  "lastVerified": "2026-04-15"
}
```

Pi does not use `_meta`; its version is in `package.json` → `version`.

## Mandatory workflow — updating plugins to a new agent version

Follow these steps in order. **Never push to `main` directly.**

### 1. Detect version drift

```bash
gh release list --repo github/copilot-cli --limit 5      # latest Copilot CLI
gh release list --repo github/copilot-sdk --limit 5      # latest Copilot SDK
```

Compare each result against `_meta.copilotCliVersion` / `_meta.copilotSdkVersion` in every `plugins/*/plugin.json`.

### 2. Analyse the changelog delta

For each version gap found, read the relevant changelog sections:

- **CLI**: <https://github.com/github/copilot-cli/blob/main/changelog.md>
- **SDK**: <https://github.com/github/copilot-sdk/blob/main/CHANGELOG.md>

Identify every change that affects agents, hooks, skills, extensions, or MCP configuration.

### 3. Create a feature branch

```bash
git checkout main && git pull --ff-only
git checkout -b chore/<plugin-name>-v<new-version>
```

### 4. Update each affected plugin

For each plugin with a version gap:

1. Read the plugin's own `AGENTS.md` (if present) — it contains plugin-specific update procedures and must be followed exactly.
2. Update agents, hooks, skills, resources, and MCP configuration to reflect the changelog delta.
3. Update `_meta.copilotCliVersion`, `_meta.copilotSdkVersion`, and `_meta.lastVerified` in `plugin.json`.
4. Bump `plugin.json` → `version` (patch unless the change is breaking or adds features).
5. **Sync `gemini-extension.json` version** to match `plugin.json` → `version`.
6. Update the plugin's `CHANGELOG.md` with top-level bullets only (no nested/sub-bullets), following [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) — see the `git` skill's `resources/git-release.md` (in [`e-roux/agent-skills`](https://github.com/e-roux/agent-skills)) for the full format spec.

### 5. Sync the marketplace

`.claude-plugin/marketplace.json` must always match each plugin's `plugin.json` version. After bumping a plugin version:

```bash
jq '(.plugins[] | select(.source == "./plugins/<name>") | .version) = "<new-version>"' \
  .claude-plugin/marketplace.json > /tmp/mj.json && mv /tmp/mj.json .claude-plugin/marketplace.json
```

### 6. Run QA — must pass with zero errors

```bash
make qa
```

`make qa` validates JSON, checks version alignment between `plugin.json` and `marketplace.json`, confirms pi plugins have a valid `package.json`, and verifies `gemini-extension.json` versions match `plugin.json`.

Fix every failure and every warning before proceeding.

### 7. Commit, push, and open the release PR

Follow **Phase 1** of the `git` skill's release workflow (`skills/git/resources/git-release.md`):

```bash
git add -A
git commit -m "chore(<plugin>): bump to v<new-version> — copilot-cli v<cli> / sdk v<sdk>

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
git push -u origin chore/<plugin-name>-v<new-version>
```

Open the PR with `mcp__git-ops__create_pr` (preferred, platform-agnostic) or `gh pr create`; merge with `mcp__git-ops__merge_pr` (preferred) or `gh pr merge --squash --delete-branch`.

### 8. Tag and publish the release

Follow **Phases 2–3** of the same release workflow. Monorepo tags are scoped per plugin:

```bash
git checkout main && git pull --ff-only
git tag -a <plugin>/v<new-version> -m "Release <plugin> v<new-version>"
git push origin <plugin>/v<new-version>
```

For plugins with compiled Go MCP servers, run `make release` in the plugin directory **before** tagging — it cross-compiles and must attach binaries at release-creation time, not separately after.

Create the platform release with `mcp__git-ops__create_release` (preferred — auto-detects GitHub/GitLab/Azure DevOps) or the platform CLI (`gh release create` / `glab release create`), using the plugin's `CHANGELOG.md` section for this version as release notes.

## Pi plugins

Pi support is indicated by `package.json` containing a `"pi"` key. Pi plugins do not use `_meta` version fields — keep `package.json` → `version` in sync with `plugin.json` → `version` manually when bumping.

Pi-enabled plugins: `make`, `dev`, `infra`.

## Quick reference

| Command | Purpose |
|---------|---------|
| `make qa` | Full quality gate (fmt + lint + typecheck + test) |
| `make verify` | Version drift check: plugin.json vs marketplace.json |
| `make verify-pi` | Pi plugins have valid package.json with `pi` key |
| `make verify-gemini` | All plugins have gemini-extension.json aligned with plugin.json |
| `make fmt` | Validate all JSON files |
| `make update.list` | List currently installed plugins (copilot + claude + gemini) |


## Mac M (Apple Silicon) Compilation & GitHub Release Workflow

Since we do not run a remote CI/CD pipeline, the release of pre-compiled binaries for Mac M (Apple Silicon - arm64, no Intel x64 support) must be performed manually and attached directly to the GitHub Release on every new version.

### 1. Local Compilation & Installation (XDG_BIN_HOME Only)

To compile the latest `mcp-git-ops` binary locally for Apple Silicon (Mac M) and install it into your local path, run:

```bash
CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 GOBIN=${XDG_BIN_HOME:-$HOME/.local/bin} go install ./plugins/dev/mcp-git-ops
```

This compiles the binary natively for `arm64` and places it directly into `${XDG_BIN_HOME:-$HOME/.local/bin}`. Ensure this directory is in your user shell's `$PATH` so Gemini CLI can execute the tool via the `"mcp-git-ops"` command.

### 2. Packaging for GitHub Releases (Always on New Version)

Whenever a new version of `e-roux-plugins-all` is released, you must create and upload a platform-specific tarball containing the root extension configuration and the compiled Mac M binary:

1. **Clean compile the binary** locally for Mac M:
   ```bash
   CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -o plugins/dev/mcp-git-ops/mcp-git-ops ./plugins/dev/mcp-git-ops
   ```

2. **Package the entire extension** root including the manifest, hooks, context instructions, and compiled binary into a rootless tarball:
   ```bash
   mkdir -p build
   tar -czf build/darwin.arm64.e-roux-plugins-all.tar.gz \
     gemini-extension.json \
     hooks/ \
     GEMINI.md \
     plugins/dev/mcp-git-ops/mcp-git-ops \
     plugins/dev/gemini-extension.json \
     plugins/dev/hooks/ \
     plugins/infra/gemini-extension.json \
     plugins/infra/hooks/ \
     plugins/make/gemini-extension.json \
     plugins/make/hooks/ \
     plugins/vulcan/gemini-extension.json \
     plugins/vulcan/hooks/
   ```

3. **Delete the transient binary** from your local work tree to keep git clean:
   ```bash
   rm plugins/dev/mcp-git-ops/mcp-git-ops
   ```

4. **Attach the archive** `build/darwin.arm64.e-roux-plugins-all.tar.gz` to the GitHub Release (using `gh release create` or `mcp_git-ops_create_release`). 

When users run `gemini extensions install https://github.com/e-roux/agent-plugins.git`, Gemini's installer automatically pulls the Mac M (`darwin.arm64`) tarball asset and installs it cleanly on their machine!
