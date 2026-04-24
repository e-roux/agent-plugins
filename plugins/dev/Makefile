SHELL := /bin/bash
.SILENT:
.ONESHELL:
.DEFAULT_GOAL := help

BATS         := bats
SHELLCHECK   := shellcheck
TEST_DIR     := test
HOOKS_SCRIPTS := hooks/scripts
MCP_DIR      := mcp-git-ops

VERSION := $(shell jq -r .version plugin.json 2>/dev/null || echo "unknown")

.PHONY: help sync fmt lint typecheck check qa clean distclean
.PHONY: test test.unit
.PHONY: mcp.build mcp.install mcp.test

check: lint
qa: check test
test: test.unit

sync:
	command -v bats       >/dev/null || brew install bats-core
	command -v shellcheck >/dev/null || brew install shellcheck
	$(MAKE) -C $(MCP_DIR) sync
	$(MAKE) -C $(MCP_DIR) install

fmt:
	find $(HOOKS_SCRIPTS) -name '*.sh' -exec shellcheck -f gcc {} + 2>/dev/null || true

lint:
	find $(HOOKS_SCRIPTS) -name '*.sh' -exec shellcheck {} +

typecheck:
	$(MAKE) -C $(MCP_DIR) typecheck

test.unit:
	$(BATS) $(TEST_DIR)/copilot-cli/hooks.bats
	$(MAKE) -C $(MCP_DIR) test.unit

mcp.build:
	$(MAKE) -C $(MCP_DIR) build

mcp.install:
	$(MAKE) -C $(MCP_DIR) install

mcp.test:
	$(MAKE) -C $(MCP_DIR) test.unit

clean:
	rm -f hooks/logs/*.log
	$(MAKE) -C $(MCP_DIR) clean

distclean: clean

help:
	printf "\033[36m"
	printf "╔═╗╦  ╦ ╦╔═╗ ╦ ╔╗╔\n"
	printf "╠═╝║  ║ ║║╠╗ ║ ║║║\n"
	printf "╝  ╩═╝╚═╝╚═╝ ╩ ╝╚╝\n"
	printf "\033[0m\n"
	printf "Usage: make [target]\n\n"
	printf "\033[1;35mSetup:\033[0m\n"
	printf "  sync            - Install deps (bats, shellcheck) + build mcp-git-ops\n"
	printf "\n"
	printf "\033[1;35mDev:\033[0m\n"
	printf "  fmt             - Format shell scripts\n"
	printf "  lint            - Lint shell scripts\n"
	printf "  check           - lint\n"
	printf "  qa              - check + test (quality gate)\n"
	printf "\n"
	printf "\033[1;35mTest:\033[0m\n"
	printf "  test            - Run all tests (bats + Go)\n"
	printf "  test.unit       - bats + Go unit tests\n"
	printf "\n"
	printf "\033[1;35mMCP server:\033[0m\n"
	printf "  mcp.build       - Build mcp-git-ops binary\n"
	printf "  mcp.install     - Install mcp-git-ops to XDG_BIN_HOME\n"
	printf "  mcp.test        - Run mcp-git-ops Go tests\n"
	printf "\n"
	printf "\033[1;35mCleanup:\033[0m\n"
	printf "  clean           - Remove artifacts\n"
	printf "  distclean       - Deep clean\n"
