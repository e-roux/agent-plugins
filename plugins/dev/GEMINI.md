---
name: dev
description: "General-purpose development guards. Enforces: no hardcoded secrets, no direct main pushes, no destructive SQL migrations, no --no-verify bypasses, self-documenting code, and CI pipeline monitoring."
---

# Dev Guards — Active

These guards apply to every repository in this session.

## Mandatory workflow — before editing any file

1. Check current branch: `git branch --show-current`
2. If on `main`/`master`, create and switch to a feature branch: `git checkout -b <type>/<descriptive-slug>`
3. Only then begin making changes

## 1. Secrets Guard

Never hardcode credentials in source files. Use environment variables.

```go
// ✗ Forbidden
JWT_SECRET := "my-super-secret-key-here"

// ✓ Correct
JWT_SECRET := os.Getenv("JWT_SECRET")
```

Applies to all code files except tests, templates, and markdown.

## 2. Branch Guard

Never push or merge directly to `main` or `master`. Use a PR:

```bash
git checkout -b feat/my-feature
# ... make changes ...
git push -u origin feat/my-feature
gh pr create --base main
```

Also forbidden: `git commit --no-verify` — this bypasses commit hooks.

## 3. Branch-First Guard

Never edit or create files while on `main` or `master`. The `BeforeTool` hook blocks `write_file` and `replace` on protected branches.

## 4. Migration Guard

SQL migrations must be additive only. No `DROP TABLE`, `TRUNCATE TABLE`, or `DELETE FROM` in migration files (`migrations?/` or `*.sql`).

```sql
-- ✗ Forbidden in migration files
DROP TABLE users;

-- ✓ Correct
ALTER TABLE users ADD COLUMN display_name TEXT;
```

## 5. No-Comments Guard

Code must be self-documenting — no comment lines in source files.

Applies to: `.go`, `.ts`, `.tsx`, `.js`, `.jsx`, `.py`, `.rs`, `.java`, `.c`, `.cpp`, `.h`, `.cs`, `.rb`, `.swift`, `.kt`
Does NOT apply to: tests, Makefiles, shell scripts, config files (`.json`, `.yaml`, `.toml`), markdown. Shebang lines (`#!/`) are always allowed.

```go
// ✗ Forbidden
// handleAuth processes the authentication request
func handleAuth(r *http.Request) error {

// ✓ Correct
func processAuthenticationRequest(r *http.Request) error {
```

## 6. QA Gate Guard

`git commit` is blocked unless `make qa` passes with zero errors. Run `make qa` before committing.

## 7. Pipeline Chainguard

After every `git push`, check CI pipeline status before continuing:

```bash
sleep 15 && gh run list --branch <branch> --limit 3 --json status,conclusion,name
gh run watch --exit-status
```

If the pipeline fails, diagnose and fix before proceeding.

## Guard Scope

These guards are project-agnostic — they apply to every repository in the session. Hook scripts enforce guards at the `BeforeTool` event for `write_file`, `replace`, and `run_shell_command`.
