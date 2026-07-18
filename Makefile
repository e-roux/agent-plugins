SHELL := /bin/bash
.SILENT:
.ONESHELL:
.DEFAULT_GOAL := help

PLUGINS    := dev vulcan infra
PI_PLUGINS := make dev infra
JQ         := jq

PLUGIN_DIRS  := $(patsubst plugins/%/Makefile,%,$(wildcard plugins/*/Makefile))
QA_PLUGINS   := $(addprefix qa/,$(PLUGIN_DIRS))
BUILD_PLUGINS   := $(addprefix build/,$(PLUGIN_DIRS))
INSTALL_PLUGINS := $(addprefix install/,$(PLUGIN_DIRS))
CLEAN_PLUGINS   := $(addprefix clean/,$(PLUGIN_DIRS))

.PHONY: help sync fmt lint typecheck check qa clean distclean
.PHONY: test test.unit test.integration test.e2e
.PHONY: verify.versions verify.pi changelog
.PHONY: update update.list
.PHONY: build install install.agents

check: fmt lint typecheck
qa: check test $(QA_PLUGINS)
test: test.unit

sync:
	command -v $(JQ) >/dev/null || { printf "FAIL: jq not found\n"; exit 1; }
	command -v gh    >/dev/null || { printf "FAIL: gh not found\n"; exit 1; }
	command -v git   >/dev/null || { printf "FAIL: git not found\n"; exit 1; }
	mkdir -p .git/hooks && ln -sf ../../hooks/scripts/pre-push .git/hooks/pre-push
	printf "  OK tools present and local pre-push Git hook installed\n"

fmt:
	fail=0
	for f in $$(find plugins -name "plugin.json" -o -name "package.json" -o -name "copilot.json" -o -name "hooks.json") .claude-plugin/marketplace.json marketplace.json; do
		$(JQ) . "$$f" >/dev/null 2>&1 || { printf "FAIL: invalid JSON: %s\n" "$$f"; fail=1; }
	done
	[ $$fail -eq 0 ] && printf "  OK JSON valid\n" || exit 1

lint: verify.versions verify.pi changelog

typecheck:
	printf "  OK no compiled sources\n"

verify.versions:
	fail=0
	for plugin in $(PLUGINS); do
		dir="plugins/$$plugin"
		pjson="$$dir/plugin.json"
		cjson="$$dir/.claude-plugin/plugin.json"
		[ ! -f "$$pjson" ] && { printf "FAIL: %s missing\n" "$$pjson"; fail=1; continue; }
		plugin_ver=$$($(JQ) -r .version "$$pjson")
		market_ver=$$($(JQ) -r ".plugins[] | select(.source == \"./$$dir\") | .version" .claude-plugin/marketplace.json)
		root_mkt_ver=$$($(JQ) -r ".plugins[] | select(.source == \"./$$dir\") | .version" marketplace.json 2>/dev/null)
		ok=1
		[ -z "$$market_ver" ] && { printf "FAIL: %-14s not found in .claude-plugin/marketplace.json\n" "$$plugin"; fail=1; ok=0; }
		[ "$$plugin_ver" != "$$market_ver" ] && { printf "FAIL: %-14s plugin.json=v%s .claude-plugin/marketplace.json=v%s\n" "$$plugin" "$$plugin_ver" "$$market_ver"; fail=1; ok=0; }
		[ -n "$$root_mkt_ver" ] && [ "$$plugin_ver" != "$$root_mkt_ver" ] && { printf "FAIL: %-14s plugin.json=v%s marketplace.json=v%s\n" "$$plugin" "$$plugin_ver" "$$root_mkt_ver"; fail=1; ok=0; }
		if [ -f "$$cjson" ]; then
			claude_ver=$$($(JQ) -r .version "$$cjson")
			[ "$$plugin_ver" != "$$claude_ver" ] && { printf "FAIL: %-14s plugin.json=v%s .claude-plugin/plugin.json=v%s\n" "$$plugin" "$$plugin_ver" "$$claude_ver"; fail=1; ok=0; }
		fi
		if [ -f "$$dir/package.json" ]; then
			pkg_ver=$$($(JQ) -r .version "$$dir/package.json")
			[ "$$plugin_ver" != "$$pkg_ver" ] && { printf "FAIL: %-14s plugin.json=v%s package.json=v%s\n" "$$plugin" "$$plugin_ver" "$$pkg_ver"; fail=1; ok=0; }
		fi
		[ $$ok -eq 1 ] && printf "  OK %-14s v%s\n" "$$plugin" "$$plugin_ver"
	done
	[ $$fail -eq 0 ] || exit 1

verify.pi:
	fail=0
	for plugin in $(PI_PLUGINS); do
		dir="plugins/$$plugin"
		if [ ! -f "$$dir/package.json" ]; then
			printf "FAIL: %s/package.json missing\n" "$$dir"; fail=1
		elif ! $(JQ) -e '.pi' "$$dir/package.json" >/dev/null 2>&1; then
			printf "FAIL: %s/package.json has no 'pi' key\n" "$$dir"; fail=1
		else
			printf "  OK %-14s pi-package\n" "$$plugin"
		fi
	done
	[ $$fail -eq 0 ] || exit 1

changelog:
	cl="CHANGELOG.md"
	[ -f "$$cl" ] || { printf "FAIL: %s not found\n" "$$cl"; exit 1; }
	grep -q '^## \[Unreleased\]' "$$cl" || { printf "FAIL: %s missing [Unreleased] section\n" "$$cl"; exit 1; }
	bad=$$(grep -E '^### ' "$$cl" | grep -vE '^### (Added|Changed|Deprecated|Removed|Fixed|Security)$$' | head -1)
	[ -z "$$bad" ] || { printf "FAIL: invalid changelog section header: %s\n" "$$bad"; exit 1; }
	printf "  OK changelog\n"

test.unit: verify.versions verify.pi changelog

test.integration:
	printf "  OK no integration tests\n"

test.e2e:
	printf "  OK no e2e tests\n"

clean: $(CLEAN_PLUGINS)

distclean: clean

update:
	if command -v copilot >/dev/null 2>&1; then
		printf "  → copilot\n"
		copilot plugin marketplace update 2>/dev/null
		copilot plugin update --all 2>&1
	else
		printf "  ⚠ copilot not found\n"
	fi
	if command -v claude >/dev/null 2>&1; then
		printf "  → claude\n"
		claude plugin marketplace update 2>/dev/null
		claude plugin list --json 2>/dev/null | $(JQ) -r '.[].id' | \
		while IFS= read -r p; do
			claude plugin uninstall "$$p" 2>/dev/null
			claude plugin install "$$p" 2>&1
		done
	else
		printf "  ⚠ claude not found\n"
	fi

update.list:
	if command -v copilot >/dev/null 2>&1; then
		printf "copilot:\n"
		copilot plugin list 2>/dev/null | grep '•' || printf "  (none)\n"
	else
		printf "  ⚠ copilot not found\n"
	fi
	if command -v gemini >/dev/null 2>&1; then
		printf "gemini:\n"
		gemini extensions list -o json 2>&1 | grep -v '^\[TELEMETRY\]\|^Timeout of\|^The .metricReader' | $(JQ) -r '.[] | "  • \(.name) (v\(.version))"' || printf "  (none)\n"
	else
		printf "  ⚠ gemini not found\n"
	fi
	if command -v claude >/dev/null 2>&1; then
		printf "claude:\n"
		claude plugin list --json 2>/dev/null | $(JQ) -r '.[] | "  • \(.id) (v\(.version))"' || printf "  (none)\n"
	else
		printf "  ⚠ claude not found\n"
	fi

build: $(BUILD_PLUGINS)

install: $(INSTALL_PLUGINS) install.agents

install.agents:
	@plugins=$$($(JQ) -r '.plugins[].name' .claude-plugin/marketplace.json); \
	for name in $$plugins; do \
		printf "  → copilot plugin install %s@e-roux-plugins\n" "$$name"; \
		copilot plugin install "$$name@e-roux-plugins" 2>&1 || true; \
	done

qa/%:
	printf "\033[1;34m── qa: %s ──\033[0m\n" "$*"
	$(MAKE) --no-print-directory -C plugins/$* qa

build/%:
	$(MAKE) --no-print-directory -C plugins/$* build

install/%:
	$(MAKE) --no-print-directory -C plugins/$* install

clean/%:
	$(MAKE) --no-print-directory -C plugins/$* clean

help:
	printf "\033[36m"
	printf "╔═╗╦  ╦ ╦╔═╗ ╦ ╔╗╔╔═╗\n"
	printf "╠═╝║  ║ ║║╠╗ ║ ║║║╚═╗\n"
	printf "╝  ╩═╝╚═╝╚═╝ ╩ ╝╚╝╚═╝\n"
	printf "\033[0m\n"
	printf "Usage: make [target]\n\n"
	printf "\033[1;35mSetup:\033[0m\n"
	printf "  sync            Check required tools (jq, gh, git)\n"
	printf "\n"
	printf "\033[1;35mValidation:\033[0m\n"
	printf "  verify.versions Version drift: plugin.json = gemini-extension.json = marketplace.json\n"
	printf "  verify.pi       pi-enabled plugins have package.json with pi key\n"
	printf "  changelog       CHANGELOG.md has [Unreleased] and valid section headers\n"
	printf "  fmt             Validate all JSON files are well-formed\n"
	printf "  lint            verify.versions + verify.pi + changelog\n"
	printf "  check           fmt + lint + typecheck\n"
	printf "  qa              check + test + qa in all plugins (use -j for parallel)\n"
	printf "\n"
	printf "\033[1;35mCleanup:\033[0m\n"
	printf "  clean           Remove build artifacts\n"
	printf "  distclean       Deep clean\n"
	printf "\n"
	printf "\033[1;35mAgents:\033[0m\n"
	printf "  update          Update all installed plugins (Copilot + Gemini + Claude)\n"
	printf "  update.list     List installed plugins across all agents\n"
	printf "\n"
	printf "\033[1;35mBuild:\033[0m\n"
	printf "  build           Build MCP servers across all plugins (parallel)\n"
	printf "  install         Install MCP servers to XDG_BIN_HOME (parallel)\n"
	printf "  install.agents  Install all plugins from marketplace (e-roux-plugins)\n"