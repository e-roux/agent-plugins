# agent-plugins — Agent Instructions

Mono-repo of agent plugins and built-in skill suites for ##GitHub Copilot CLI_##, ##Claude Code_##, ##Gemini CLI_##, and ##pi_## coding agent.

## Repository Layout

```
agent-plugins/
├── plugins/
│   ├── dev/           ### general development guards (secrets, comments, branches, migrations, CI)
│   │   ├── mcp-git-ops/ ### embedded git-ops MCP server source
│   │   └── skills/git/ ### embedded git skill (SKILL.md + guides)
│   ├── infra/         ### infrastructure & Molecule deployment guards
│   ├── make/          ### Makefile-first workflow enforcement
│   └── vulcan/        ### Copilot CLI plugin-development expert
├── .claude-plugin/
│   └── marketplace.json ### version registry consumed by `copilot/claude plugin update`
├── Makefile           ### top-level QA: fmt / lint / typecheck / test / qa
└── CHANGELOG.md
```

Each plugin directory contains:
- `plugin.json` — Copilot CLI manifest (specifies `"hooks": "hooks/copilot.json"` and `"skills": "skills/"`)
- `package.json` — Pi manifest (carries `"pi"` with `"extensions"` and `"skills"`)
- `gemini-extension.json` — Gemini CLI manifest (specifies `"hooks": "hooks/gemini.json"` and auto-loaded context file)
- `.claude-plugin/plugin.json` — Claude Code manifest (contains direct inline `"hooks"` to prevent resolution conflicts)
- `GEMINI.md` — Gemini CLI context file (standalone behavioral instructions loaded at session start)
- `AGENTS.md` (when present) — plugin-specific agent instructions

### Skills and MCP Servers

To support seamless local packaging and cross-agent auto-discovery:
* **Built-in Skills_**: General skills (e.g. `dev-guards`, `ansible-molecule`, `makefile`) live in the standalone [e-roux/agent-skills](https://github.com/e-roux/agent-skills) repository and are installed with `skills add`. However, the specialized **`git` skill_** is packaged locally inside `plugins/dev/skills/git/` so it is natively available to all agents.
* **Embedded MCP Servers_**: The Go-based **`mcp-git-ops`_** MCP server source is embedded directly inside `plugins/dev/mcp-git-ops/` for local compilation and release packaging.

## Agent Version Tracking

Versions are tracked across all agents to prevent drift. Keep versions identical across `plugin.json` (Copilot), `package.json` (Pi), `.claude-plugin/plugin.json` (Claude), and `gemini-extension.json` (Gemini):

```json
"_meta": {
  "copilotCliVersion": "1.0.27",
  "copilotSdkVersion": "0.2.2",
  "lastVerified": "2026-04-15"
}
```

Pi and Gemini manifests use their respective root `"version"` property (no `_meta` object).

## Mandatory Workflow — Updating and Releasing Plugins

Follow these steps in order. **Never push to `main` directly._**

### 1. Detect Version Drift

Check the upstream repository releases:
```bash
gh release list --repo github/copilot-cli --limit 5      ### latest Copilot CLI
gh release list --repo github/copilot-sdk --limit 5      ### latest Copilot SDK
```
Compare each result against `_meta` in your plugin manifests.

### 2. Analyse the Upstream Changes

Read the changelog delta to identify changes affecting hooks, skills, or MCP configurations:
- **CLI**: <https://github.com/github/copilot-cli/blob/main/changelog.md>
- **SDK**: <https://github.com/github/copilot-sdk/blob/main/CHANGELOG.md>

### 3. Create a Feature Branch

```bash
git checkout main && git pull --ff-only
git checkout -b chore/<plugin-name>-v<new-version>
```

### 4. Implement Plugin Updates

1. Apply manifest and code updates to match the upstream changes.
2. Update version fields across **all four manifest formats_** (`plugin.json`, `package.json`, `.claude-plugin/plugin.json`, and `gemini-extension.json`).
3. Update the plugin's `CHANGELOG.md` following [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
4. Sync the `.claude-plugin/marketplace.json` to match:
   ```bash
   jq '(.plugins[] | select(.source == "./plugins/<name>") | .version) = "<new-version>"' \
     .claude-plugin/marketplace.json > /tmp/mj.json && mv /tmp/mj.json .claude-plugin/marketplace.json
   ```

### 5. Run Quality Gates

```bash
make qa
```
`make qa` validates JSON, checks version alignment, and verifies that `gemini-extension.json` and `package.json` match `plugin.json` versions with zero errors.

### 6. Local Compilation & Installation (Mac M - Apple Silicon)

Since there is no remote CI/CD pipeline, Go-based MCP servers (like `mcp-git-ops`) must be compiled locally for Mac M (Apple Silicon - arm64, no Intel support) and installed into your local path:

```bash
CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 GOBIN=${XDG_BIN_HOME:-$HOME/.local/bin} go install ./plugins/dev/mcp-git-ops
```

This ensures the binary is installed directly in `${XDG_BIN_HOME:-$HOME/.local/bin}` which is globally accessible in your shell's `$PATH`.

### 7. Commit, Push, and Merge PR

```bash
git add -A
git commit -m "chore(<plugin>): bump to v<new-version> — copilot-cli v<cli> / sdk v<sdk>"
git push -u origin chore/<plugin-name>-v<new-version>
```
Open a pull request and squash-merge it cleanly into `main` after checks pass.

### 8. Tag and Publish the Release

1. Checkout and update `main`:
   ```bash
   git checkout main && git pull --ff-only
   ```
2. Tag the plugin release:
   ```bash
   git tag -a <plugin>/v<new-version> -m "Release <plugin> v<new-version>"
   git push origin <plugin>/v<new-version>
   ```
3. **Compile the Release Binary_** for Mac M:
   ```bash
   CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -o plugins/dev/mcp-git-ops/mcp-git-ops ./plugins/dev/mcp-git-ops
   ```
4. **Package the Gemini Extension Tarball_**:
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
5. Remove the transient binary from your local work tree:
   ```bash
   rm plugins/dev/mcp-git-ops/mcp-git-ops
   ```
6. Create the GitHub Release and attach `build/darwin.arm64.e-roux-plugins-all.tar.gz` as a release asset (using `gh release create`).

## Quick Reference

| Command | Purpose |
|---------|---------|
| `make qa` | Full quality gate (fmt + lint + typecheck + test) |
| `make verify` | Version drift check: plugin.json vs marketplace.json |
| `make verify-pi` | Pi plugins have valid package.json with `pi` key |
| `make verify-gemini` | All plugins have gemini-extension.json aligned with plugin.json |
| `make fmt` | Validate all JSON files |
| `make update.list` | List currently installed plugins (copilot + claude + gemini) |
