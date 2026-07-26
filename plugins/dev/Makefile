SHELL := /bin/bash
.SILENT:
.ONESHELL:
.DEFAULT_GOAL := help

BATS         := bats
SHELLCHECK   := shellcheck
TEST_DIR     := test
HOOKS_SCRIPTS := hooks/scripts
MCP_MODULE   := github.com/e-roux/mcp-git-ops
override GOBIN := $(or $(XDG_BIN_HOME),$(HOME)/.local/bin)

VERSION := $(shell jq -r .version plugin.json 2>/dev/null || echo "unknown")

.PHONY: help sync fmt lint typecheck check qa clean distclean
.PHONY: test test.unit build install changelog

check: lint changelog
qa: check test
test: test.unit

sync:
	command -v bats       >/dev/null || brew install bats-core
	command -v shellcheck >/dev/null || brew install shellcheck
	printf "  OK dependencies present (run 'make install' for mcp-git-ops binary)\n"

fmt:
	if [ -d $(HOOKS_SCRIPTS) ] && [ $$(find $(HOOKS_SCRIPTS) -name '*.sh' | wc -l) -gt 0 ]; then find $(HOOKS_SCRIPTS) -name '*.sh' -exec shellcheck -f gcc {} +; fi

lint:
	if [ -d $(HOOKS_SCRIPTS) ] && [ $$(find $(HOOKS_SCRIPTS) -name '*.sh' | wc -l) -gt 0 ]; then find $(HOOKS_SCRIPTS) -name '*.sh' -exec shellcheck {} +; fi

changelog:
	cl="CHANGELOG.md"
	[ -f "$$cl" ] || { printf "FAIL: %s not found\n" "$$cl"; exit 1; }
	grep -q '^## \[Unreleased\]' "$$cl" || { printf "FAIL: %s missing [Unreleased] section\n" "$$cl"; exit 1; }
	bad=$$(grep -E '^### ' "$$cl" | grep -vE '^### (Added|Changed|Deprecated|Removed|Fixed|Security)$$' | head -1)
	[ -z "$$bad" ] || { printf "FAIL: invalid changelog section header: %s\n" "$$bad"; exit 1; }
	printf "  OK changelog\n"

typecheck:
	printf "  OK no local compiled sources (mcp-git-ops lives in github.com/e-roux/mcp-git-ops)\n"

build: compile install

compile:
	printf "  → Bundling dev hooks using Bun\n"
	bun build hooks/src/pre-tool.ts --outfile hooks/scripts/pre-tool.js --target node
	bun build hooks/src/post-tool.ts --outfile hooks/scripts/post-tool.js --target node
	bun build hooks/src/session-start.ts --outfile hooks/scripts/session-start.js --target node
	bun build hooks/src/branch-check-turn.ts --outfile hooks/scripts/branch-check-turn.js --target node
	bun build hooks/src/pipeline-chainguard.ts --outfile hooks/scripts/pipeline-chainguard.js --target node

install:
	GOBIN=$(GOBIN) go install $(MCP_MODULE)@latest
	printf "  OK installed mcp-git-ops -> %s/mcp-git-ops\n" "$(GOBIN)"

test.unit:
	$(BATS) $(TEST_DIR)/copilot-cli/hooks.bats

clean:
	rm -f hooks/logs/*.log
	rm -f hooks/scripts/*.js

distclean: clean

help:
	printf "\033[36m"
	printf "╔═╗╦  ╦ ╦╔═╗ ╦ ╔╗╔\n"
	printf "╠═╝║  ║ ║║╠╗ ║ ║║║\n"
	printf "╝  ╩═╝╚═╝╚═╝ ╩ ╝╚╝\n"
	printf "\033[0m\n"
	printf "Usage: make [target]\n\n"
	printf "\033[1;35mSetup:\033[0m\n"
	printf "  sync            - Install deps (bats, shellcheck)\n"
	printf "  install         - go install mcp-git-ops (github.com/e-roux/mcp-git-ops) to XDG_BIN_HOME\n"
	printf "\n"
	printf "\033[1;35mDev:\033[0m\n"
	printf "  build           - Alias for install (no local Go sources, binary is go-installed)\n"
	printf "  fmt             - Format shell scripts\n"
	printf "  lint            - Lint shell scripts\n"
	printf "  check           - lint + changelog\n"
	printf "  qa              - check + test (quality gate)\n"
	printf "\n"
	printf "\033[1;35mTest:\033[0m\n"
	printf "  test            - Run all tests (bats)\n"
	printf "  test.unit       - bats unit tests\n"
	printf "\n"
	printf "\033[1;35mCleanup:\033[0m\n"
	printf "  clean           - Remove artifacts\n"
	printf "  distclean       - Deep clean\n"
