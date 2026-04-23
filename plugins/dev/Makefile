SHELL := /bin/bash
.SILENT:
.ONESHELL:
.DEFAULT_GOAL := help

BATS         := bats
SHELLCHECK   := shellcheck
TEST_DIR     := test

HOOKS_SCRIPTS := hooks/scripts

VERSION := $(shell jq -r .version plugin.json 2>/dev/null || echo "unknown")

.PHONY: help sync fmt lint typecheck check qa clean distclean
.PHONY: test test.unit

check: lint
qa: check test
test: test.unit

sync:
	command -v bats      >/dev/null || brew install bats-core
	command -v shellcheck >/dev/null || brew install shellcheck

fmt:
	find $(HOOKS_SCRIPTS) -name '*.sh' -exec shellcheck -f gcc {} + 2>/dev/null || true

lint:
	find $(HOOKS_SCRIPTS) -name '*.sh' -exec shellcheck {} +

typecheck:
	true

test.unit:
	$(BATS) $(TEST_DIR)/copilot-cli/hooks.bats

clean:
	rm -f hooks/logs/*.log

distclean: clean

help:
	printf "\033[36m"
	printf "╔═╗╦  ╦ ╦╔═╗ ╦ ╔╗╔\n"
	printf "╠═╝║  ║ ║║╠╗ ║ ║║║\n"
	printf "╝  ╩═╝╚═╝╚═╝ ╩ ╝╚╝\n"
	printf "\033[0m\n"
	printf "Usage: make [target]\n\n"
	printf "\033[1;35mSetup:\033[0m\n"
	printf "  sync            - Install dependencies (bats, shellcheck)\n"
	printf "\n"
	printf "\033[1;35mDev:\033[0m\n"
	printf "  fmt             - Format shell scripts\n"
	printf "  lint            - Lint shell scripts\n"
	printf "  check           - lint\n"
	printf "  qa              - check + test (quality gate)\n"
	printf "\n"
	printf "\033[1;35mTest:\033[0m\n"
	printf "  test            - Run all tests\n"
	printf "  test.unit       - Run bats unit tests\n"
	printf "\n"
	printf "\033[1;35mCleanup:\033[0m\n"
	printf "  clean           - Remove log files\n"
	printf "  distclean       - Deep clean\n"
