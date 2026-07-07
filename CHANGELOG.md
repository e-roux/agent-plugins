# Changelog

## [Unreleased]

- refactor(repo/skills): migrate `plugins/dev/skills/{dev,git}`, `plugins/infra/skills/ansible-molecule`, and `plugins/make/skills/{banner,makefile,python,shell,testing}` to [`e-roux/agent-skills`](https://github.com/e-roux/agent-skills) — the canonical, agent-agnostic home for skill content; drop the `"skills"` field from `plugin.json`/`package.json` for `dev`, `infra`, and `make` (`vulcan`'s bundled skills are unaffected — they document plugin authoring in this repo and stay local)
- refactor(dev/mcp): remove embedded `mcp-git-ops` Go source from `plugins/dev/mcp-git-ops/` — now maintained standalone at [`e-roux/mcp-git-ops`](https://github.com/e-roux/mcp-git-ops); `plugins/dev/Makefile` `install`/`build` targets now run `go install github.com/e-roux/mcp-git-ops@latest` instead of delegating to a local module; `typecheck`/`test.unit`/`sync` no longer reference local Go sources
- docs(repo/readme): update `README.md`/`AGENTS.md` to describe skills and `mcp-git-ops` as externalized companion repos; drop stale `pi install ... --skill plugins/dev/skills` example and remaining `web-browser` plugin references
- refactor(repo/marketplace): remove deleted billing and web-browser plugins from marketplace configuration and build tooling
- fix(Makefile/verify): replace verify + verify-gemini + verify-pi with verify.versions + verify.pi; add Gemini to update/update.list; fix update.list to use JSON output for all agents; no hyphenated target names
- feat(repo/makefile): add silent `build`/`install` targets — probe each plugin with `make -n` before delegating, no explicit MCP_PLUGINS list needed; fix `override GOBIN` in mcp-git-ops to always install to `$XDG_BIN_HOME`

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
