---
name: web-browser
description: "CDP-based Chrome automation for web design verification: navigate, interact, and inspect live browser state using the web-browser skill."
---

# Web Browser — CDP Automation

Activate the **web-browser** skill for Chrome/Chromium automation via the Chrome DevTools Protocol (CDP).

## Prerequisites

Chrome or Chromium must be running with remote debugging enabled on port 9222:

```bash
google-chrome --remote-debugging-port=9222 --no-first-run --no-default-browser-check
# or
chromium --remote-debugging-port=9222
```

## Quick Reference

```bash
./scripts/start.js                        # launch Chrome (fresh profile)
./scripts/nav.js https://example.com      # navigate to URL
./scripts/eval.js 'document.title'        # run JS in active tab
./scripts/click.js 'button[type="submit"]' # click by CSS selector
./scripts/type.js 'input[name="q"]' 'hello' --clear  # type text
./scripts/wait.js '.modal' --visible --timeout 5000  # poll for condition
./scripts/a11y.js --roles 'button,link'   # accessibility tree
./scripts/perf.js                         # CDP metrics + Web Vitals
./scripts/screenshot.js out.png           # capture screenshot
```

## Skills Available

- **web-browser** — activate for full script reference and interaction patterns
