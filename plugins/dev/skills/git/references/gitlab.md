---
name: glab
description: "Repository specific glab CLI preferences. Use when dealing with glab, gitlab, and gitlab ci pipeline."
---

# Glab CLI — Non-Interactive Pitfall Guide

Use this skill whenever running `glab` commands in an agent shell. Many `glab` subcommands open interactive TUIs, spawn pagers, or prompt for user selection — all of which **block the shell indefinitely** until a human intervenes.

## Golden Rules
0. **ALWAYS** use `PAGER=/bin/cat` in glab commands. This is NOT NEGOCIABLE. E.g. `PAGER=/bin/cat glab mr list`
1. **Prefer `--output json`** — machine-readable. Use this first.
3. **Always supply explicit IDs or names** — avoids interactive selection prompts.
4. **Set `GITLAB_TOKEN`** — avoids the `glab auth login` interactive wizard.

> **`cat` alias warning**: `bat` is a popular `cat` replacement. When `cat` is aliased to `bat`, piping to `| cat` invokes `bat`, which uses a pager when stdout is a TTY or when `BAT_PAGER` / `--paging=always` is configured. Use `command cat` or `/usr/bin/cat` to guarantee the real binary.

---

## Repository Management

### Creation
```bash
glab repo create <namespace>/<repo> --public   # or --private / --internal
```

**Pitfall**: The `--push` flag is unavailable in older CLI versions. Push manually instead:
```bash
git remote add origin https://gitlab.example.com/<namespace>/<repo>.git
git push -u origin main
```

### Change Default Branch (when CLI flag is absent)
```bash
glab api projects/:id -X PUT -f "default_branch=main"
```

---

## CI/CD Troubleshooting

### Streaming Job Logs Without TUI
```bash
## Repository Management
PAGER=/bin/cat glab ci status --output json         # pipeline overview
PAGER=/bin/cat glab ci trace <job-id>               # full log for a specific job
```

### Finding a Job ID
```bash
PAGER=/bin/cat glab pipeline list --output json                     # find pipeline IDs
PAGER=/bin/cat glab api "projects/:id/pipelines/<pipeline-id>/jobs" # list jobs
```

### Common Failures

| Symptom | Cause | Fix |
|---|---|---|
| Build fails with "unsupported Go version" | `go.mod` version > CI image version | Align `go.mod` with the CI image tag |
| Remote-host tests fail on shared runners | No network access to private hosts | Guard with `if os.Getenv("CI") != "" { t.Skip(...) }` |
| `glab` command hangs forever | Pager or interactive prompt | Add `\| command cat` or provide the missing flag/ID |
