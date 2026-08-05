SHELL := /bin/bash
.SILENT:
.ONESHELL:
.DEFAULT_GOAL := help

.PHONY: help compile clean qa check lint test

check: lint
qa: check test
test:
	printf "  OK no local tests for web\n"

lint:
	printf "  OK no local linting for web\n"

build:

install:
	printf "  OK no binary install step for web\n"

clean:
	rm -f hooks/logs/*.log

help:
	printf "Usage: make [target]\n"
