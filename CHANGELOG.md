# Changelog

## [Unreleased]

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
