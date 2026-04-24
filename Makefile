SHELL := /bin/bash
.SILENT:
.ONESHELL:
.DEFAULT_GOAL := help

PLUGINS    := make dev vulcan infra web-browser
PI_PLUGINS := make dev infra web-browser
JQ         := jq

PLUGIN_DIRS  := $(patsubst plugins/%/Makefile,%,$(wildcard plugins/*/Makefile))
QA_PLUGINS   := $(addprefix qa/,$(PLUGIN_DIRS))
BUILD_PLUGINS   := $(addprefix build/,$(PLUGIN_DIRS))
INSTALL_PLUGINS := $(addprefix install/,$(PLUGIN_DIRS))
CLEAN_PLUGINS   := $(addprefix clean/,$(PLUGIN_DIRS))

.PHONY: help sync fmt lint typecheck check qa clean distclean
.PHONY: test test.unit test.integration test.e2e
.PHONY: verify verify-pi
.PHONY: update update.list
.PHONY: build install

check: fmt lint typecheck
qa: check test $(QA_PLUGINS)
test: test.unit

sync:
	command -v $(JQ) >/dev/null || { printf "FAIL: jq not found\n"; exit 1; }
	command -v gh    >/dev/null || { printf "FAIL: gh not found\n"; exit 1; }
	command -v git   >/dev/null || { printf "FAIL: git not found\n"; exit 1; }
	printf "  OK tools present (jq, gh, git)\n"

fmt:
	fail=0
	for f in $$(find plugins -name "plugin.json" -o -name "package.json") .claude-plugin/marketplace.json; do
		$(JQ) . "$$f" >/dev/null 2>&1 || { printf "FAIL: invalid JSON: %s\n" "$$f"; fail=1; }
	done
	[ $$fail -eq 0 ] && printf "  OK JSON valid\n" || exit 1

lint: verify verify-pi

typecheck:
	printf "  OK no compiled sources\n"

verify:
	fail=0
	for plugin in $(PLUGINS); do
		dir="plugins/$$plugin"
		if [ ! -f "$$dir/plugin.json" ]; then
			printf "FAIL: %s/plugin.json missing\n" "$$dir"; fail=1; continue
		fi
		plugin_ver=$$($(JQ) -r .version "$$dir/plugin.json" 2>/dev/null)
		market_ver=$$($(JQ) -r ".plugins[] | select(.source == \"./$$dir\") | .version" .claude-plugin/marketplace.json 2>/dev/null)
		if [ -n "$$market_ver" ] && [ "$$plugin_ver" != "$$market_ver" ]; then
			printf "FAIL: %-14s plugin.json=v%s but marketplace.json=v%s\n" "$$plugin" "$$plugin_ver" "$$market_ver"; fail=1
		else
			printf "  OK %-14s v%s\n" "$$plugin" "$$plugin_ver"
		fi
	done
	[ $$fail -eq 0 ] || exit 1

verify-pi:
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

test.unit: verify verify-pi

test.integration:
	printf "  OK no integration tests\n"

test.e2e:
	printf "  OK no e2e tests\n"

clean: $(CLEAN_PLUGINS)

distclean: clean

update:
	if command -v copilot >/dev/null 2>&1; then
		copilot plugin list 2>/dev/null | grep '•' | awk '{print $$2}' | \
		while IFS= read -r p; do copilot plugin update "$$p"; done
	else
		printf "  ⚠ copilot not found\n"
	fi
	if command -v claude >/dev/null 2>&1; then
		claude plugin list --json 2>/dev/null | $(JQ) -r '.[].id' | \
		while IFS= read -r p; do claude plugin update "$$p"; done
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
	if command -v claude >/dev/null 2>&1; then
		printf "claude:\n"
		claude plugin list --json 2>/dev/null | $(JQ) -r '.[].id' | sed 's/^/  /' || printf "  (none)\n"
	else
		printf "  ⚠ claude not found\n"
	fi

build: $(BUILD_PLUGINS)

install: $(INSTALL_PLUGINS)

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
	printf "  sync         - Check required tools (jq, gh, git)\n"
	printf "\n"
	printf "\033[1;35mValidation:\033[0m\n"
	printf "  verify       - Version drift: plugin.json vs marketplace.json\n"
	printf "  verify-pi    - pi-enabled plugins have package.json with pi key\n"
	printf "  fmt          - Validate all JSON files are well-formed\n"
	printf "  lint         - verify + verify-pi\n"
	printf "  check        - fmt + lint + typecheck\n"
	printf "  qa           - check + test + qa in all plugins (use -j for parallel)\n"
	printf "\n"
	printf "\033[1;35mCleanup:\033[0m\n"
	printf "  clean        - Remove build artifacts\n"
	printf "  distclean    - Deep clean\n"
	printf "\n"
	printf "\033[1;35mAgents:\033[0m\n"
	printf "  update       - Update all installed plugins (copilot + claude)\n"
	printf "  update.list  - List installed plugins for all agents\n"
	printf "\n"
	printf "\033[1;35mBuild:\033[0m\n"
	printf "  build        - Build MCP servers across all plugins (parallel)\n"
	printf "  install      - Install MCP servers to XDG_BIN_HOME (parallel)\n"
