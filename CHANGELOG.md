# Changelog

## [Unreleased]

- feat(dev/mcp): migrate mcp-git-ops source into mono-repo at `plugins/dev/mcp-git-ops/`; update module path, add skill-conformant Makefile, delegate sync/test/typecheck from `plugins/dev/Makefile`

- fix(repo/monorepo): remove stray `.git` dirs from plugins/dev and plugins/vulcan — completing mono-repo migration (nested repos were leftover from old sibling-repo workflow)

- feat(repo/makefile): add `make update` / `make update.list` targets — update or list all installed copilot + claude plugins; mirrors `agents plugin update/list` logic inline

- fix(dev/mcp): mirror mcp-rb-resources pattern — `type:local`, `bash -c`, `${XDG_BIN_HOME:-$HOME/.local/bin}/mcp-git-ops`, `tools:["*"]`; install binary with `GOBIN=$XDG_BIN_HOME go install ...` or symlink from go bin
- refactor(repo/makefile): rewrite Makefile to score ≥6 — full standard targets (sync/fmt/lint/typecheck/test*/clean/distclean), PLUGINS banner, explicit printf help
- fix(dev/mcp): use `bash -lc exec mcp-git-ops` — Copilot CLI MCP schema requires `args` array (bare `command` fails ZodError); login shell ensures Go bin dir is in PATH
- fix(marketplace): bump dev version to 0.8.0 in marketplace.json (was stuck at 0.7.1)
- chore(makefile): verify now cross-checks marketplace.json versions against plugin.json

## [2026-04-24]

- feat: convert to mono-repo — remove rsync-from-sibling-repos workflow
- feat: add pi coding agent support for make, dev, infra, and web-browser plugins
- feat(dev): port all guards (secrets, comments, branch-first, migration, no-verify, pipeline-chainguard, secret-redaction) to pi TypeScript extension
- feat(make): port Makefile validator and command redirect guards to pi TypeScript extension
- feat(infra): port Ansible/Molecule guards to pi TypeScript extension
- feat(web-browser): add pi package.json — skills work as-is via Agent Skills standard
- chore: add verify-pi target to Makefile for pi package validation
- docs: update README with tri-agent compatibility table and pi install instructions
