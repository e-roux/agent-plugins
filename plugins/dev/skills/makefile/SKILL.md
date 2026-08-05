---
name: makefile
description: "Use when creating, adding, or editing a Makefile in any project. Enforces .SILENT:, .ONESHELL:, no @ prefix, mandatory qa target, and make-only workflow."
---

# Makefile Skill

**CRITICAL**: Every project MUST have a Makefile. It is the MANDATORY interface for all development tasks.

## Core Mandate

**Step 0 — always**: If no Makefile exists yet, create one from `resources/Makefile.template` BEFORE doing anything else. Adapt it to the project's language and toolchain.

Once a Makefile exists, you MUST use `make` targets exclusively:

```bash
make sync      # Restore dependencies
make fmt       # Format code
make lint      # Lint and auto-fix
make typecheck # Type validation
make test      # Run unit tests
make check     # fmt + lint + typecheck
make qa        # MANDATORY before completion: check + test
```

You ARE NOT ALLOWED to run direct commands:
```bash
# ✗ FORBIDDEN
pytest / ruff format / ruff check / go test / go build / eslint / jest / bun test / black
```

> **Hook enforcement**: Direct invocations of the above tools are **auto-redirected** to the corresponding `make` target by the plugin's `preToolUse` hook. The agent learns the pattern through `additionalContext` that persists across turns (CLI ≥1.0.25). The hook uses `COPILOT_PLUGIN_ROOT` (CLI ≥1.0.26) for reliable path resolution.

---

## Required Makefile Directives

Every Makefile MUST include all four directives at the top:

```makefile
SHELL := /bin/bash
.SILENT:
.ONESHELL:
.DEFAULT_GOAL := help
```

> **Hook enforcement**: Creating or editing a Makefile without these directives is **denied** by the plugin's `preToolUse` hook.

---

## FORBIDDEN
### Commands in recipes

No command directly written in the recipe, use variables!

```makefile
# ✗ WRONG — pytest directly called from the recipe
test:
	pytest tests/

# ✓ CORRECT
UV      := uv
PYTEST 	:= $(UV) run python -m pytest
test:
	$(PYTEST) tests/
```

### `@` Prefix in Recipes

**NEVER** use the `@` prefix in recipe lines. `.SILENT:` already suppresses all echoing.

```makefile
# ✗ WRONG — @ is redundant and forbidden
PYTEST  := pytest

test:
	@$(PYTEST) tests/

# ✓ CORRECT
test:
	$(PYTEST) tests/
```

> **Hook enforcement**: Adding `@` to recipe lines is **denied** by the plugin's `preToolUse` hook.

### Use Makefile variables when possible

Stay DRY and use Makefile capabilites!

```makefile
# ✗ WRONG: use Makefile variables! 
.git/hooks/pre-push: hooks/scripts/pre-push
	mkdir -p .git/hooks
	ln -sf hooks/scripts/pre-push .git/hooks/pre-push
	$(info   OK pre-push hook installed)

# ✓ CORRECT
.git/hooks/pre-push: hooks/scripts/pre-push
	mkdir -p $(@D)
	ln -sf $< $@
	$(info   OK pre-push hook installed)
```
### Create a `.PHONY` rule when a concrete file can be used
If your command generates a specific physical file, do not use .PHONY. Target
the concrete file instead so Make can skip unnecessary builds.

```makefile
.PHONY: sync

# ✗ WRONG — `@` is redundant and forbidden
sync: 
	mkdir -p .git/hooks/
	ln -sf hooks/scripts/pre-push .git/hooks/pre-push 
	$(info   OK pre-push hook installed)

# ✓ CORRECT
.git/hooks/pre-push: hooks/scripts/pre-push
	mkdir -p $(@D)
	ln -sf $< $@
	$(info   OK pre-push hook installed)

sync: .git/hooks/pre-push
```

### Avoid creating .PHONY targets that solely act as aliases for real file targets 

> Exceptions are  `build`, `clean`, `distclean`, `doc`, `fmt`, `lint`, `qa`,
> `sync`, `test`, `typecheck` that act as structural entry points.

```makefile
data/models.yaml: input/data.py
	printf "Creating $@:\n"
	$(RTK) $(PYTHON) $<
	printf "\n"

# ✗ WRONG: Creating an unnecessary alias target
.PHONY: data.models
data.models: data/models.yaml
```


models.schema: schema/pipeline-models.v1.json
---
## Standard Targets

All projects provide these targets:

| Target | Purpose |
|:---|:---|
| `sync` | Restore dependencies |
| `fmt` | Format code |
| `lint` | Lint + auto-fix |
| `typecheck` | Type validation |
| `test` | Run unit tests |
| `test.unit` | Unit tests only (excludes integration/e2e) |
| `test.integration` | Integration tests (requires running services) |
| `test.e2e` | End-to-end tests (requires deployed stack) |
| `check` | All checks (`fmt + lint + typecheck`) |
| `qa` | Quality gate (`check + test` — **MUST PASS**) |
| `clean` | Remove temporary artifacts |
| `distclean` | Deep clean (clean + dist/) |

---

## Agent Protocol

```
Development Progress:
- [ ] 0. Create Makefile from Makefile.template if absent (ALWAYS first)
- [ ] 0.5. Validate Makefile with scripts/validate.sh (score must be ≥6)
- [ ] 1. Restore environment: make sync
- [ ] 2. Implement changes (write tests FIRST)
- [ ] 3. Verify tests: make test
- [ ] 4. Quality check: make check
- [ ] 5. Final gate: make qa (MUST PASS)
```

**Do NOT stop working until `make qa` passes.**

---

## Makefile Evaluation Scale

| Score | Level | Requirements |
|:---:|:---:|:---|
| 1 | Rudimentary | Makefile exists. Commands hardcoded. Only PHONY targets. |
| 2 | Basic | Variables for tool paths. Partial target compliance. |
| 3 | Functional | All mandatory standard targets implemented. |
| 4 | Proper | `.PHONY:`, `.DEFAULT_GOAL:`, `.SILENT:`, `.ONESHELL:` present. |
| 5 | Polished | `help` uses double-line box-drawing header (generated via the `scripts/banner.sh` script) and categorised output. |
| 6 | Advanced | **Strict `.SILENT:` compliance — ZERO `@` prefixes in recipes.** |
| 7 | Professional | Real file targets as prerequisites (dependency graph). |
| 8 | Expert | Grouped targets (`&:`), pattern rules, auto-dependencies. |

**Minimum acceptable score: 6.**

---

## Help Design

The `help` target **always** uses Approach A: a box-drawing header with explicit `printf` entries.
Approach B (inline `##` annotations + `grep` pipeline) is **FORBIDDEN** — both the hook and the validator will reject it.

### Approach A: Box-drawing header + explicit printf (mandatory)

Keep output on **one terminal screen** (≤24 lines):
- **5 sections** max (Setup, Dev, Test, Docs, Info)
- **Max 10 character** section titles
- **3–4 items per section**
- **ASCII art header** generated by the banner script
- **Colors**: Magenta (`\033[1;35m`) for sections, Cyan (`\033[36m`) for header

**Generating a banner — MANDATORY: use `scripts/banner.sh`**

> **CRITICAL**: Run `bash skills/makefile/scripts/banner.sh` to generate banners.
> Running without arguments uses the repo basename (git root, truncated to 12 chars).
> Pass a custom string to override: `bash skills/makefile/scripts/banner.sh "MAKE"`.
> **NEVER** attempt to build banners manually, letter-by-letter, or from any JSON data.
> The script is the ONLY supported method. Manual assembly ALWAYS produces broken output.

The script prints 3-row box-drawing art — paste it directly into the `help` target:

```makefile
help:
	printf "\033[36m"
	printf "<row 0 from banner.sh>\n"
	printf "<row 1 from banner.sh>\n"
	printf "<row 2 from banner.sh>\n"
	printf "\033[0m\n"
```

Example — `bash skills/makefile/scripts/banner.sh "MAKE"` returns:
```
╔╦╗╔═╗╦╔ ╔═╗
║║║╠═╣╠╩╗║╣ 
╝ ╝╝ ╝╝ ╝╚═╝
```

So the `help` target becomes:
```makefile
help:
	printf "\033[36m"
	printf "╔╦╗╔═╗╦╔ ╔═╗\n"
	printf "║║║╠═╣╠╩╗║╣ \n"
	printf "╝ ╝╝ ╝╝ ╝╚═╝\n"
	printf "\033[0m\n"
```

### Banner Rules
- **Input**: letters A–Z and spaces. Case-insensitive. 1–12 characters recommended for a single terminal line.
- **Output**: exactly 3 rows separated by `\n`, no trailing newline.
- **Unknown characters** silently fall back to the space glyph.

---

## Templates

Base template: [resources/Makefile.template](resources/Makefile.template)
Validator: [scripts/validate.sh](scripts/validate.sh)

## Resources

Web development: [references/web.md](references/web.md) — CSS custom property conventions, component architecture, accessibility baseline, Make targets for web projects, design system integration pattern, and web component testing.
