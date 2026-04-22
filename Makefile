SHELL := /bin/bash
.SILENT:
.ONESHELL:
.DEFAULT_GOAL := help

PLUGIN_SRC_ROOT ?= $(HOME)/development/github.com/e-roux

PLUGINS := make dev vulcan infra web-browser
RSYNC_EXCLUDE := --exclude='.git' --exclude='.gitignore' \
	--exclude='test' --exclude='Makefile' --exclude='.cursor' --exclude='.github'

.PHONY: help sync verify qa

sync:
	@for plugin in $(PLUGINS); do \
		src="$(PLUGIN_SRC_ROOT)/agent-plugin-$$plugin"; \
		if [ -d "$$src" ]; then \
			rsync -a --delete $(RSYNC_EXCLUDE) "$$src/" "plugins/$$plugin/"; \
			printf "  synced %-10s → %s\n" "$$plugin" "$$(jq -r .version plugins/$$plugin/plugin.json 2>/dev/null)"; \
		else \
			printf "  SKIP   %-10s (source not found: %s)\n" "$$plugin" "$$src"; \
		fi \
	done

verify:
	@fail=0; \
	for plugin in $(PLUGINS); do \
		dir="plugins/$$plugin"; \
		if [ ! -f "$$dir/plugin.json" ]; then \
			printf "FAIL: %s/plugin.json missing\n" "$$dir"; fail=1; \
		else \
			printf "  OK %-10s v%s\n" "$$plugin" "$$(jq -r .version $$dir/plugin.json)"; \
		fi \
	done; \
	[ $$fail -eq 0 ] || exit 1

qa: verify

help:
	printf "Usage: make [target]\n\n"
	printf "  sync     - Copy plugin source repos into plugins/ (requires local checkouts)\n"
	printf "  verify   - Check all plugins have plugin.json\n"
	printf "  qa       - Run verification checks\n"
