# Web Browser Script Reference

All scripts connect to Chrome on `localhost:9222` via CDP. Run `start.js` first.

## Session

| Script | Purpose | Key flags |
|---|---|---|
| `start.js` | Launch Chrome with remote debugging | `--profile` (copy user profile, has cookies) |
| `tabs.js` | List open tabs with title/url/targetId | `--json` |
| `nav.js` | Navigate current tab or open new tab | `--new` |

## DOM Interaction

| Script | Purpose | Key flags |
|---|---|---|
| `eval.js <expr>` | Evaluate JS in active tab | — |
| `click.js <selector>` | Click element (real mouse events) | `--index N`, `--force` |
| `type.js <selector> <text>` | Type text (framework-aware) | `--clear` |
| `wait.js <selector>` | Poll until selector condition met | `--visible`, `--gone`, `--timeout <ms>` |
| `pick.js <description>` | Interactive element picker | Cmd+click multi-select |
| `upload_file.js <selector> <path>` | Set file input value | — |
| `dismiss-cookies.js` | Auto-dismiss EU cookie banners | `--reject` |

## Inspection

| Script | Purpose | Key flags |
|---|---|---|
| `screenshot.js` | Capture viewport → temp file | — |
| `a11y.js` | Accessibility tree (AX roles, names, states) | `--selector <css>`, `--roles <r,r>`, `--json` |
| `perf.js` | CDP metrics + Nav Timing + Web Vitals (FP/FCP/LCP/CLS) | `--json` |
| `net-summary.js` | Network request/response summary from log | — |

## Logging

Logs are JSONL files written to `~/.cache/agent-web/logs/YYYY-MM-DD/<targetId>.jsonl`.
`start.js` and `watch.js` start logging automatically.

| Script | Purpose | Key flags |
|---|---|---|
| `watch.js` | Start console+network JSONL logger | — |
| `logs-tail.js` | Print current log and exit | `--follow` |
| `console.js` | Parse JSONL log; filter messages | `--errors`, `--level <lvl>`, `--last <N>` |

## Typical workflows

**Debug a form submission:**
```bash
./scripts/nav.js http://localhost:5173/login
./scripts/wait.js 'form' --visible
./scripts/type.js 'input[name="email"]' 'user@example.com' --clear
./scripts/type.js 'input[name="password"]' 'secret' --clear
./scripts/click.js 'button[type="submit"]'
./scripts/wait.js '.dashboard' --visible --timeout 5000
```

**Inspect accessibility:**
```bash
./scripts/a11y.js --selector 'main'        # subtree rooted at <main>
./scripts/a11y.js --roles 'button,link'    # filter to interactive elements
```

**Check performance after navigation:**
```bash
./scripts/nav.js http://localhost:5173/
./scripts/wait.js 'main' --visible
./scripts/perf.js
```

**Audit network errors:**
```bash
./scripts/net-summary.js
./scripts/console.js --errors
```
