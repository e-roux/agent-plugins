---
name: web-browser
description: "Allows to interact with web pages by performing actions such as clicking buttons, filling out forms, and navigating links. It works by remote controlling Google Chrome or Chromium browsers using the Chrome DevTools Protocol (CDP). When an agents needs to browse the web, it can use this skill to do so."
license: Mario Zechner
---

# Web Browser Skill

CDP-based Chrome automation. All scripts live in `scripts/` and connect to Chrome on `localhost:9222`.
Full script reference: `references/commands.md`.

## Quick start

```bash
./scripts/start.js              # launch Chrome (fresh profile)
./scripts/nav.js https://example.com
```

## Interact

```bash
./scripts/eval.js 'document.title'                    # run JS in active tab
./scripts/click.js 'button[type="submit"]'            # click by CSS selector
./scripts/type.js 'input[name="q"]' 'hello' --clear  # type text (framework-aware)
./scripts/wait.js '.modal' --visible --timeout 5000   # poll for condition
./scripts/upload_file.js 'input[type="file"]' /tmp/f  # set file input
```

## Inspect

```bash
./scripts/a11y.js --roles 'button,link'    # accessibility tree, filter by role
./scripts/a11y.js --selector 'main'        # AX subtree rooted at element
./scripts/perf.js                          # CDP metrics + Web Vitals (FP/FCP/LCP/CLS)
./scripts/net-summary.js                   # network request/response summary
./scripts/tabs.js                          # list open tabs
```

## Logs (console + network, JSONL)

```bash
./scripts/logs-tail.js          # dump current session log
./scripts/console.js --errors   # filter to errors only
./scripts/console.js --last 20  # last N log entries
```

## DOM verification

Do **not** use screenshots for verification — vision is not available.
Use `eval.js` to read DOM state:
```bash
./scripts/eval.js 'document.querySelector(".status")?.textContent'
./scripts/eval.js 'document.querySelectorAll("li").length'
```

See `references/commands.md` for all flags and workflow examples.
