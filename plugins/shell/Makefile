SHELL := /bin/bash
.SILENT:
.ONESHELL:
.DEFAULT_GOAL := help

.PHONY: help compile clean qa check lint test

check: lint
qa: check test
test:
	printf "  OK no local tests for shell\n"

lint:
	printf "  OK no local linting for shell\n"

build:

install:
	printf "  OK no binary install step for shell\n"

clean:
	rm -f hooks/logs/*.log

help:
	printf "Usage: make [target]\n"
