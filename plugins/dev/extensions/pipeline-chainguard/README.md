# Pipeline Chainguard Extension

Automated CI pipeline monitoring for Copilot CLI sessions. After every `git push`, this extension:

1. Detects the push via `onPostToolUse`
2. Waits for the CI pipeline to register (configurable delay)
3. Polls pipeline status until completion
4. If the pipeline **fails**, sends the failure logs back to the agent with instructions to fix

## Installation

Copy to your project's extensions directory:

```bash
mkdir -p .github/extensions/pipeline-chainguard
cp extension.mjs .github/extensions/pipeline-chainguard/
```

Then reload in your Copilot session:
```
extensions_reload
```

## Features

### Automatic CI Monitoring (`session.idle`)

When the agent finishes a turn after pushing code, the extension automatically:
- Waits 18 seconds for CI to register
- Polls `gh run list` every 15 seconds (up to 5 minutes)
- Logs success silently
- Sends failure details back to the agent via `session.send()`

### Manual Tool: `check_ci_pipeline`

The agent can call this tool directly:

```
check_ci_pipeline(branch: "feat/my-feature", wait: true)
```

Parameters:
- `branch` (optional): Git branch to check. Defaults to current branch.
- `wait` (optional): If `true`, polls until pipeline completes.

### CI Provider Detection

Automatically detects GitHub Actions (`gh`) or GitLab CI (`glab`) based on authenticated CLI tools.

## Relationship to copilot-plugin-dev

This extension is the **opt-in Layer 2** of the pipeline chainguard. Layer 1 is the `postToolUse` shell hook in the dev plugin that injects `additionalContext` after every push — it works everywhere the plugin is installed.

Use this extension when you want:
- **Fully automated** CI checking (no agent action needed)
- **Self-healing loop** — failures are automatically fed back to the agent
- A dedicated `check_ci_pipeline` **custom tool** the agent can call

Most projects only need Layer 1. Add this extension for mission-critical repos.

## Remote Sessions

When using `--remote` or `/remote` to control a CLI session remotely, the pipeline chainguard extension remains active. All push detection, polling, and failure reporting work identically in remote-controlled sessions.
