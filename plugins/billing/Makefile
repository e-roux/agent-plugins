SHELL := /bin/bash
.SILENT:
.ONESHELL:
.DEFAULT_GOAL := help

BATS    := bats
VERSION := $(shell jq -r .version plugin.json 2>/dev/null || echo "0.0.0")

.PHONY: help sync fmt lint typecheck check qa clean distclean install
.PHONY: test test.unit test.integrity

check: lint
qa: check test
test: test.unit
test.unit: test.integrity

sync:
	command -v bats >/dev/null || brew install bats-core
	command -v jq   >/dev/null || { printf "FAIL: jq required\n"; exit 1; }

fmt:
	true

lint:
	shellcheck hooks/scripts/*.sh scripts/*.sh 2>/dev/null || true

typecheck:
	true

test.integrity:
	$(BATS) test/plugin_integrity.bats

clean:
	true

install:
	true

distclean: clean

help:
	printf "billing plugin v%s\n" "$(VERSION)"
	printf "Targets: qa check lint test\n"
