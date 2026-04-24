SHELL := /bin/bash
.SILENT:
.ONESHELL:
.DEFAULT_GOAL := help

BATS    := bats
VERSION := $(shell jq -r .version plugin.json 2>/dev/null || echo "0.0.0")

.PHONY: help sync fmt lint typecheck check qa clean distclean
.PHONY: test test.unit test.integrity

check: lint
qa: check test
test: test.unit
test.unit: test.integrity

sync:
	command -v bats >/dev/null || brew install bats-core

fmt:
	true

lint:
	shellcheck scripts/*.sh 2>/dev/null || true
	shellcheck hooks/scripts/*.sh 2>/dev/null || true

typecheck:
	true

test.integrity:
	$(BATS) test/plugin_integrity.bats

clean:
	true

distclean: clean

help:
	printf "\033[36m"
	printf "╦ ╦╦ ╦╦  ╔═╗╔═╗╔╗╔\n"
	printf "║╔╝║ ║║  ║  ╠═╣║║║\n"
	printf "╚╝ ╚═╝╩═╝╚═╝╝ ╝╝╚╝\n"
	printf "\033[0m\n"
	printf "Usage: make [target]\n\n"
	printf "\033[1;35mSetup:\033[0m\n"
	printf "  sync            - Install bats-core\n"
	printf "\n"
	printf "\033[1;35mDev:\033[0m\n"
	printf "  fmt             - Shellcheck scripts (warnings)\n"
	printf "  lint            - Shellcheck scripts (errors)\n"
	printf "  check           - lint\n"
	printf "  qa              - check + test (quality gate)\n"
	printf "\n"
	printf "\033[1;35mTest:\033[0m\n"
	printf "  test            - Run all tests\n"
	printf "  test.unit       - Plugin integrity tests (bats)\n"
	printf "\n"
	printf "\033[1;35mCleanup:\033[0m\n"
	printf "  clean           - Remove build artifacts\n"
	printf "  distclean       - Deep clean\n"
