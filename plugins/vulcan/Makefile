SHELL := /bin/bash
.SILENT:
.ONESHELL:
.DEFAULT_GOAL := help

BATS    := bats
VERSION := $(shell jq -r .version plugin.json 2>/dev/null || echo "0.0.0")

.PHONY: help sync fmt lint typecheck check qa clean distclean
.PHONY: test test.integrity

check: lint
qa: check test
test: test.integrity

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
	printf "v — make qa to validate plugin integrity\n" "$(VERSION)"
