SHELL := /bin/bash
.SILENT:
.ONESHELL:
.DEFAULT_GOAL := help

.PHONY: help compile clean qa check lint test

check: lint
qa: check test
test:
	printf "  OK no local tests for infra\n"

lint:
	printf "  OK no local linting for infra\n"

compile:
	printf "  → Bundling infra hooks using Bun\n"
	bun build hooks/src/pre-tool.ts --outfile hooks/scripts/pre-tool.js --target node
	bun build hooks/src/session-start.ts --outfile hooks/scripts/session-start.js --target node

build: compile

install:
	printf "  OK no binary install step for infra\n"

clean:
	rm -f hooks/logs/*.log
	rm -f hooks/scripts/*.js

help:
	printf "Usage: make [target]\n"
