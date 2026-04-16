# Changelog

## [0.11.8]

- Remove stale `.mcp.json` — `mcp-banner` was replaced by `skills/banner/` in v0.11.4; zombie file caused `claude mcp list` to report a failed server

## [0.11.7]

- Fix dual-manifest schema: `.claude-plugin/plugin.json` minimal for Claude Code; root `plugin.json` full for Copilot CLI
- Split hooks: `hooks/policy.json` (PascalCase, Claude Code) and `hooks/policy.copilot.json` (camelCase, Copilot CLI)

## [0.11.6]

- Move plugin manifest to `.claude-plugin/plugin.json` — DRY path for both Copilot CLI and Claude Code

## [0.11.5]

- Align with Vulcan v0.18.0 dual-tool DRY guidance (no content changes — plugin has no `.agents/skills/` references to migrate)

## [0.11.4]

- Bump Copilot CLI version to 1.0.27 (SDK unchanged at 0.2.2)
- Use `COPILOT_PLUGIN_ROOT` env var (CLI 1.0.26) in hook scripts for robust path resolution, with fallback to `dirname "$0"` for backward compatibility
- Redirect biome format/lint/check, vitest, tsc, svelte-check to make targets
- Update makefile skill: document `COPILOT_PLUGIN_ROOT` usage in hook enforcement note

## [0.11.3]

- Bump Copilot CLI version to 1.0.25
- Update makefile skill: document auto-redirect behavior and skill instruction persistence across turns (CLI 1.0.25)
- Update python skill: clarify that mypy is auto-redirected (not denied) while python/pip/virtualenv remain denied
- Update AGENTS.md: add `/env` command for interactive debugging of plugin loading in E2E tests

## [0.11.2]

- Transform direct-tool-call enforcement from deny to auto-redirect via `modifiedArgs` (CLI v1.0.24): `pytest`→`make test`, `ruff`→`make lint/fmt`, `go test`→`make test`, `go build`→`make build`, `golangci-lint`/`eslint`→`make lint`, `jest`/`bun test`→`make test`, `black`→`make fmt`, `mypy`→`make typecheck`; agent learns the pattern through `additionalContext`

## [0.11.1]

- Bump Copilot CLI version to 1.0.24; no content changes

## [0.11.0]

- Migrate `mcp-banner` Go MCP server to a pure bash skill (`skills/banner/banner.sh`)
- Add `skills/banner/` skill: `banner.sh` renders box-drawing banners via a single `jq` call against `letters.json` — no binary build required
- Remove Go source (`src/`), pre-compiled binaries (`bin/mcp-banner-*`), MCP wrapper (`bin/mcp-banner.sh`), and `.mcp.json` server registration
- Remove `"mcpServers"` field from `plugin.json`; version bumped to `0.11.0`
- Update `skills/makefile/SKILL.md`: banner generation now calls `bash skills/banner/banner.sh TEXT` instead of the `make_banner` MCP tool
- Update `Makefile`: remove `GO`, `MCP_DIR`, `mcp.test`, `mcp.build`, `distclean`; add `banner.test`; simplify `publish` (no binary assets)
- Update `plugin_integrity.bats`: replace MCP protocol tests with banner skill structure and render correctness tests
- Add `test/copilot-cli/banner.bats`: 12 unit tests covering empty input, single letters, MAKE/VFDE renders, case normalisation, unknown chars, newline count, and width growth

## [0.9.0]

- Ship pre-compiled binaries for all platforms (darwin/arm64, darwin/amd64, linux/amd64, linux/arm64) directly in the repository
- Replace build-from-source/auto-update wrapper with simple platform-detection wrapper — zero runtime dependencies, instant startup
- Update integrity tests to validate pre-compiled binaries and wrapper behavior

## [0.8.2]

- Remove `letters.json` from skill directory — its presence caused agents to build banners letter-by-letter instead of calling the `make_banner` MCP tool
- Strengthen SKILL.md: `make_banner` MCP tool is the ONLY supported method for banner generation; manual assembly is explicitly forbidden

## [0.8.1]

- Fix MCP wrapper: PLUGIN_DIR resolved two levels up instead of one, causing version file and fallback build to fail when installed as a plugin
- Fix MCP wrapper: `go build` fallback now `cd`s to source directory so `go.mod` is found
- Add plugin integrity test suite (`plugin_integrity.bats`): validates plugin.json, .mcp.json, wrapper paths, MCP server protocol, hooks, and skill structure

## [0.8.0]

- Add web development best practices resource to makefile skill: CSS custom property hierarchy, component architecture, accessibility baseline, Make targets for web projects, design system integration pattern, web component testing

## [0.7.0]

- Add `shell` and `testing` skills: migrate from user-level (`~/.copilot/skills/`) into plugin for proper versioning and cohesion; plugin now covers the complete Make-centric dev suite (Makefile + Python + Shell + TDD)
- Update plugin description to reflect broadened scope

## [0.6.0]

- Add cross-compile binary assets to `publish` target: darwin/arm64, darwin/amd64, linux/amd64, linux/arm64
- Add auto-update logic to `mcp-banner.sh` wrapper: checks GitHub Releases hourly for newer binaries, falls back to build-from-source

## [0.5.1]

- Bump Copilot CLI version to 1.0.22; no content changes

## [0.4.0] - 2026-04-02

### Added

- **skills/python/**: merged `agent-plugin-python` into this plugin. The Python/uv skill now lives
  at `copilot-cli/skills/python/SKILL.md`, alongside the existing Makefile skill. Includes all
  assets (`conftest.py`, `pyproject.toml.template`, `python.md`, `ruff.toml`) and resources
  (`scripts.md`, `build.md`).
- **pre-tool.sh**: merged Python toolchain guards from `agent-plugin-python`:
  - blocks direct `python`/`python3`, `pip`/`pip3`, `virtualenv` — use `uv` instead
  - blocks direct `mypy` — use `zmypy` (zuban drop-in) instead
- **skills directory restructured**: `copilot-cli/skill/` → `copilot-cli/skills/makefile/` per the
  latest copilot-cli plugin spec (skills must live in named subdirectories).
- **plugin.json**: `"skills"` path updated to `"skills/"`, version bumped to `0.4.0`, description
  and keywords updated to reflect the merged Python scope.
- **session-start.sh**: banner updated to cover both Makefile and Python toolchain rules.

## [0.3.1] - 2026-04-03

### Fixed

- **Makefile (root)**: Corrected `I` glyph in "AGENT PLUGIN MAKEFILE" banner — regenerated with `mcp-banner` tool using the centered serif `I` ( ╦ / ║ / ╩ ).
- **mcp/letters.json** + **copilot-cli/skill/assets/letters.json**: `I` glyph recentered with ╩ serif bottom (`[" ╦ ", " ║ ", " ╩ "]`) to eliminate 4-space gap before following letters.

## [0.3.0] - 2026-04-02

### Added

- **mcp/**: Go MCP server (`mcp-banner`) — exposes a `make_banner` tool that renders any string as a 3-row box-drawing banner using the double-line Unicode alphabet from `letters.json`. Eliminates error-prone hand-crafting of ASCII art in Makefile `help` targets.
- **copilot-cli/.mcp.json**: Registers the `mcp-banner` stdio server with the Copilot CLI plugin.
- **copilot-cli/plugin.json**: `"mcpServers": ".mcp.json"` — wires the MCP server into the plugin.
- **Makefile**: `mcp.test` and `mcp.build` targets; `go` added to `sync`; `distclean` now removes `copilot-cli/bin/`.

### Changed

- **Makefile (root)**: Help header migrated from block-font ASCII art to the box-drawing alphabet (`╔╦╗╔═╗╦╔ ╔═╗` / `║║║╠═╣╠╩╗║╣ ` / `╝ ╝╝ ╝╝ ╝╚═╝`).
- **copilot-cli/skill/assets/Makefile.template**: Same header fix — big block "MAKE" art replaced with the letters.json box-drawing version.
- **pre-tool.sh / validate.sh**: `##` inline annotations on target lines are now **FORBIDDEN** (Approach B removed). Any Makefile with `##`-annotated targets is denied/failed.
- **SKILL.md**: Approach B removed entirely; box-drawing `printf` help (Approach A) is the only valid pattern.

## [0.2.0] - 2026-03-28

### Added

- **pre-tool.sh**: `_validate_existing_file()` — reads the Makefile from disk on every `edit` and denies if required directives (`.SILENT:`, `.ONESHELL:`, `.DEFAULT_GOAL`) are missing, unless the edit itself adds them. Fixes the gap where a non-compliant file could be silently edited.
- **pre-tool.sh**: `_is_makefile()` helper — now detects `*.mk` include files in addition to `Makefile|makefile|GNUmakefile`.
- **SKILL.md**: documents both help approaches — Approach A (ANSI Shadow, ≤15 targets) and Approach B (inline `##` annotations + `grep` pipeline, >15 targets, preferred for large Makefiles).
- **validate.sh**: Check 3 now accepts both help approaches; auto-detects the `##` grep pipeline pattern.
- **hooks.bats**: 4 new tests for full-state validation and `*.mk` detection (38 tests, 0 failures).

### Fixed

- `hooks.bats` session-start banner test: case mismatch (`MAKEFILE POLICY` → `Makefile Policy`).

## [0.1.1] - 2026-03-17

### Added

- **opencode plugin**: proactive policy injection via three new hooks — `experimental.chat.system.transform` (policy in system prompt), `tool.definition` (bash tool description addendum), `experimental.session.compacting` (policy preserved across compaction).

## [0.1.0] - 2026-03-17

### Added

- Initial release of `agent-plugin-makefile`.
- **copilot-cli plugin**
  - `session-start` hook: displays Makefile policy banner (`.SILENT:`, `.ONESHELL:`, no `@`, `qa` required).
  - `preToolUse` hook (`pre-tool.sh`):
    - Blocks direct tool invocations via `bash`: `pytest`, `ruff format`, `ruff check`, `go test`, `go build`, `golangci-lint`, `eslint`, `jest`, `bun test`, `black`.
    - Validates Makefile content on `create` tool: enforces `.SILENT:`, `.ONESHELL:`, `.DEFAULT_GOAL`, no `@` in recipes, `qa` target.
    - Validates Makefile edits on `edit` tool: blocks adding `@` to recipes and removing required directives.
  - Skill definition (`SKILL.md`) with Makefile evaluation scale (1–8).
  - `Makefile.template` with all required directives.
  - `validate.sh` static Makefile validator.
- **opencode plugin** (`opencode-makefile-enforcer`)
  - Pure TypeScript rule engine (`core.ts`): `CommandRule`, `MakefileCheck`, `intercept()`, `validateMakefile()`.
  - Plugin entry point (`index.ts`): enforces the same policy as the copilot-cli hook for `bash`, `create`, and `edit` tools.
  - `/makefile` command documentation.
- **Test suite**
  - 34 bats unit tests for copilot-cli hooks.
  - 42 bun unit tests for opencode core rule engine.
  - E2E bats tests for both agents (real CLI invocations).
