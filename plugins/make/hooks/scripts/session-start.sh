#!/bin/bash
set -euo pipefail

PLUGIN_ROOT="${COPILOT_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
LOG_DIR="$PLUGIN_ROOT/hooks/logs"

INPUT="$(cat)"
CWD="$(echo "$INPUT" | jq -r '.cwd // "unknown"')"

jq -cn '{additionalContext: "## Makefile + Python Policy Active\n\nAll Makefiles MUST follow these rules:\n- `.SILENT:` — suppress recipe echoing\n- `.ONESHELL:` — single shell per recipe\n- `.DEFAULT_GOAL:=help` — default target is help\n- NO `@` prefix — redundant with `.SILENT:`\n- `qa:` target — MANDATORY quality gate\n\nUse make targets exclusively: `make fmt / lint / typecheck / test / qa`\n\nPython toolchain rules:\n- Never use `python`, `pip`, or `virtualenv` directly — use `uv`\n- Never use `mypy` directly — use `zmypy` (zuban drop-in)"}'

mkdir -p "$LOG_DIR" && \
  echo "session-start fired at $(date -u +%Y-%m-%dT%H:%M:%SZ), cwd=${CWD}" >> "$LOG_DIR/session-start.log" \
  || true

exit 0
