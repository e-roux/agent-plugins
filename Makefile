SHELL := /bin/bash
.SILENT:
.ONESHELL:
.DEFAULT_GOAL := help

PLUGINS := make dev vulcan infra web-browser
PI_PLUGINS := make dev infra web-browser

.PHONY: help verify verify-pi qa

verify:
	fail=0
	for plugin in $(PLUGINS); do
		dir="plugins/$$plugin"
		if [ ! -f "$$dir/plugin.json" ]; then
			printf "FAIL: %s/plugin.json missing\n" "$$dir"; fail=1
		else
			printf "  OK %-14s v%s\n" "$$plugin" "$$(jq -r .version $$dir/plugin.json 2>/dev/null)"
		fi
	done
	[ $$fail -eq 0 ] || exit 1

verify-pi:
	fail=0
	for plugin in $(PI_PLUGINS); do
		dir="plugins/$$plugin"
		if [ ! -f "$$dir/package.json" ]; then
			printf "FAIL: %s/package.json missing\n" "$$dir"; fail=1
		elif ! jq -e '.pi' "$$dir/package.json" >/dev/null 2>&1; then
			printf "FAIL: %s/package.json has no 'pi' key\n" "$$dir"; fail=1
		else
			printf "  OK %-14s pi-package\n" "$$plugin"
		fi
	done
	[ $$fail -eq 0 ] || exit 1

qa: verify verify-pi

help:
	printf "Usage: make [target]\n\n"
	printf "  verify      - Check all plugins have plugin.json (Copilot CLI / Claude Code)\n"
	printf "  verify-pi   - Check pi-enabled plugins have package.json with pi key\n"
	printf "  qa          - Run all verification checks\n"
