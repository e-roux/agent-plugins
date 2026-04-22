# agent-plugin-web-browser

CDP-based Chrome automation plugin for [Claude Code](https://claude.ai/code) and [GitHub Copilot CLI](https://github.com/github/copilot-cli).

Provides a `web-browser` skill that lets agents interact with a live Chrome or Chromium browser via the Chrome DevTools Protocol — navigate pages, click elements, type text, inspect the DOM and accessibility tree, capture performance metrics, and tail network/console logs.

Designed for **web design verification**: the agent can implement a UI change and immediately validate it in a real browser without taking screenshots.

## Install

```bash
copilot plugin install e-roux/agent-plugin-web-browser
```

## Prerequisites

Chrome or Chromium must be running with remote debugging enabled. The `start.js` script handles this:

```bash
node skills/web-browser/scripts/start.js
```

All scripts connect to `localhost:9222` via CDP.

## Setup

```bash
make sync   # install npm dependencies (ws)
```

## Scripts

| Script | Purpose |
|--------|---------|
| `start.js` | Launch Chrome with remote debugging |
| `nav.js` | Navigate to a URL |
| `click.js` | Click by CSS selector |
| `type.js` | Type text (framework-aware) |
| `eval.js` | Evaluate JS in active tab |
| `wait.js` | Poll until selector condition met |
| `a11y.js` | Accessibility tree inspection |
| `perf.js` | CDP metrics + Web Vitals |
| `net-summary.js` | Network request summary |
| `console.js` | Console log access |
| `tabs.js` | List open tabs |

See `skills/web-browser/references/commands.md` for full flag reference.

## Development

```bash
make qa     # syntax-check all scripts
```
