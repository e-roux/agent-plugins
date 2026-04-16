#!/bin/bash
set -euo pipefail

PLUGIN_ROOT="${COPILOT_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
LOG_DIR="$PLUGIN_ROOT/hooks/logs"

INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | jq -r '.toolName // empty')"
TOOL_ARGS_RAW="$(echo "$INPUT" | jq -r '.toolArgs // empty')"

# ── Helper ────────────────────────────────────────────────────────────────────

_deny() {
  local reason="$1"
  mkdir -p "$LOG_DIR" 2>/dev/null \
    && echo "denied at $(date -u +%Y-%m-%dT%H:%M:%SZ): $reason" >> "$LOG_DIR/pre-tool-denied.log" 2>/dev/null \
    || true
  jq -n --arg reason "$reason" \
    '{"permissionDecision":"deny","permissionDecisionReason":$reason}'
  exit 0
}

_redirect() {
  local original="$1" replacement="$2" target="$3"
  mkdir -p "$LOG_DIR" 2>/dev/null \
    && echo "redirected at $(date -u +%Y-%m-%dT%H:%M:%SZ): $original → $replacement" >> "$LOG_DIR/pre-tool-denied.log" 2>/dev/null \
    || true
  jq -n --arg cmd "$replacement" --arg ctx "Redirected \`$original\` → \`$replacement\`. Always use make targets (\`make $target\`) — never call tools directly." \
    '{"modifiedArgs":{"command":$cmd},"additionalContext":$ctx}'
  exit 0
}

# ── Makefile content validator ────────────────────────────────────────────────

_validate_makefile() {
  local content="$1"

  if ! echo "$content" | grep -q '^\.SILENT'; then
    _deny "Makefile missing required directive: '.SILENT:' — add it before the first target to suppress recipe echoing without @."
  fi

  if ! echo "$content" | grep -q '\.ONESHELL'; then
    _deny "Makefile missing required directive: '.ONESHELL:' — add it to run each recipe in a single shell instance."
  fi

  if ! echo "$content" | grep -q '\.DEFAULT_GOAL'; then
    _deny "Makefile missing required directive: '.DEFAULT_GOAL := help' — the default target must be 'help'."
  fi

  # Recipe lines start with a tab; @ on such lines is redundant and forbidden
  if echo "$content" | grep -qP '^\t@'; then
    _deny "Makefile has '@' prefix in recipe lines — this is redundant with '.SILENT:' and FORBIDDEN. Remove all '@' prefixes from recipes."
  fi

  # ## annotations on target lines (Approach B) are FORBIDDEN
  if echo "$content" | grep -qP '^[a-zA-Z_.][a-zA-Z_.0-9]*[^#\n]*##'; then
    _deny "Makefile has '##' inline annotations on target lines — Approach B (grep-parsed help) is FORBIDDEN. Use explicit printf entries in the help target instead (Approach A)."
  fi

  # qa target: check .PHONY declaration and actual recipe
  if ! echo "$content" | grep -qP '(?:^\.PHONY:[^\n]*\bqa\b|^qa\s*:)'; then
    _deny "Makefile missing required 'qa' target — add a 'qa:' recipe that runs 'check test' as the quality gate (e.g., 'qa: check test')."
  fi
}

# Checks that the file on disk already has required directives before allowing
# an edit.  If a directive is missing AND the new_str doesn't introduce it,
# the edit is denied — the agent must fix the non-compliance first.
_validate_existing_file() {
  local filepath="$1" new_str="$2"

  [ -f "$filepath" ] || return 0
  local current
  current="$(cat "$filepath")"

  if ! echo "$current" | grep -q '^\.SILENT' && ! echo "$new_str" | grep -q '\.SILENT'; then
    _deny "Makefile at $filepath is missing '.SILENT:' — add this directive before making other edits."
  fi

  if ! echo "$current" | grep -q '\.ONESHELL' && ! echo "$new_str" | grep -q '\.ONESHELL'; then
    _deny "Makefile at $filepath is missing '.ONESHELL:' — add this directive before making other edits."
  fi

  if ! echo "$current" | grep -q '\.DEFAULT_GOAL' && ! echo "$new_str" | grep -q '\.DEFAULT_GOAL'; then
    _deny "Makefile at $filepath is missing '.DEFAULT_GOAL' — add this directive before making other edits."
  fi
}

# ── bash tool ────────────────────────────────────────────────────────────────

if [ "$TOOL_NAME" = "bash" ]; then
  COMMAND="$(echo "$TOOL_ARGS_RAW" | jq -r '.command // empty')"

  # Matches token at command start or after shell operator (; & |)
  _matches() { echo "$COMMAND" | grep -qE "(^|[;&|][[:space:]]*)$1([[:space:]]|\$)"; }

  # pytest → make test
  if _matches "pytest"; then
    _redirect "pytest" "make test" "test"
  fi

  # ruff format → make fmt
  if echo "$COMMAND" | grep -qE '(^|[;&|][[:space:]]*)ruff[[:space:]]+format([[:space:]]|$)'; then
    _redirect "ruff format" "make fmt" "fmt"
  fi

  # ruff check → make lint
  if echo "$COMMAND" | grep -qE '(^|[;&|][[:space:]]*)ruff[[:space:]]+check([[:space:]]|$)'; then
    _redirect "ruff check" "make lint" "lint"
  fi

  # go test → make test
  if echo "$COMMAND" | grep -qE '(^|[;&|][[:space:]]*)go[[:space:]]+test([[:space:]]|$)'; then
    _redirect "go test" "make test" "test"
  fi

  # go build → make build
  if echo "$COMMAND" | grep -qE '(^|[;&|][[:space:]]*)go[[:space:]]+build([[:space:]]|$)'; then
    _redirect "go build" "make build" "build"
  fi

  # golangci-lint → make lint
  if _matches "golangci-lint"; then
    _redirect "golangci-lint" "make lint" "lint"
  fi

  # eslint → make lint
  if _matches "eslint"; then
    _redirect "eslint" "make lint" "lint"
  fi

  # biome format → make fmt
  if echo "$COMMAND" | grep -qE '(^|[;&|][[:space:]]*)biome[[:space:]]+format([[:space:]]|$)'; then
    _redirect "biome format" "make fmt" "fmt"
  fi

  # biome lint → make lint
  if echo "$COMMAND" | grep -qE '(^|[;&|][[:space:]]*)biome[[:space:]]+lint([[:space:]]|$)'; then
    _redirect "biome lint" "make lint" "lint"
  fi

  # biome check → make check
  if echo "$COMMAND" | grep -qE '(^|[;&|][[:space:]]*)biome[[:space:]]+check([[:space:]]|$)'; then
    _redirect "biome check" "make check" "check"
  fi

  # jest → make test
  if _matches "jest"; then
    _redirect "jest" "make test" "test"
  fi

  # vitest → make test
  if _matches "vitest"; then
    _redirect "vitest" "make test" "test"
  fi

  # bun test → make test
  if echo "$COMMAND" | grep -qE '(^|[;&|][[:space:]]*)bun[[:space:]]+test([[:space:]]|$)'; then
    _redirect "bun test" "make test" "test"
  fi

  # black → make fmt
  if _matches "black"; then
    _redirect "black" "make fmt" "fmt"
  fi

  # python/pip/virtualenv — keep as deny (complex arg parsing)
  FORBIDDEN_PYTHON='(^|[;&|][[:space:]]*)(python3?|pip3?|virtualenv)([[:space:]]|$)'
  if echo "$COMMAND" | grep -qE "$FORBIDDEN_PYTHON"; then
    _deny "Direct python/pip/virtualenv is forbidden. Use uv: uv run <script>, uv add <pkg>, uvx <tool>"
  fi

  # mypy → make typecheck
  if echo "$COMMAND" | grep -qE '(^|[;&|][[:space:]]*)mypy([[:space:]]|$)'; then
    _redirect "mypy" "make typecheck" "typecheck"
  fi

  # tsc → make typecheck
  if echo "$COMMAND" | grep -qE '(^|[;&|][[:space:]]*)tsc([[:space:]]|$)'; then
    _redirect "tsc" "make typecheck" "typecheck"
  fi

  # svelte-check → make typecheck (match direct and via npx)
  if _matches "svelte-check" || echo "$COMMAND" | grep -qE '(^|[;&|][[:space:]]*)npx[[:space:]]+svelte-check([[:space:]]|$)'; then
    _redirect "svelte-check" "make typecheck" "typecheck"
  fi

  # ── npm run / npx redirects ──────────────────────────────────────────────────

  # npm run test → make test
  if echo "$COMMAND" | grep -qE '(^|[;&|][[:space:]]*)npm[[:space:]]+run[[:space:]]+test([[:space:]]|$)'; then
    _redirect "npm run test" "make test" "test"
  fi

  # npm test → make test
  if echo "$COMMAND" | grep -qE '(^|[;&|][[:space:]]*)npm[[:space:]]+test([[:space:]]|$)'; then
    _redirect "npm test" "make test" "test"
  fi

  # npm run check → make check
  if echo "$COMMAND" | grep -qE '(^|[;&|][[:space:]]*)npm[[:space:]]+run[[:space:]]+check([[:space:]]|$)'; then
    _redirect "npm run check" "make check" "check"
  fi

  # npm run lint → make lint
  if echo "$COMMAND" | grep -qE '(^|[;&|][[:space:]]*)npm[[:space:]]+run[[:space:]]+lint([[:space:]]|$)'; then
    _redirect "npm run lint" "make lint" "lint"
  fi

  # npm run build → make build
  if echo "$COMMAND" | grep -qE '(^|[;&|][[:space:]]*)npm[[:space:]]+run[[:space:]]+build([[:space:]]|$)'; then
    _redirect "npm run build" "make build" "build"
  fi

  # npm run dev → make dev
  if echo "$COMMAND" | grep -qE '(^|[;&|][[:space:]]*)npm[[:space:]]+run[[:space:]]+dev([[:space:]]|$)'; then
    _redirect "npm run dev" "make dev" "dev"
  fi

  # npm run format → make fmt (catches format, format:check, format:write)
  if echo "$COMMAND" | grep -qE '(^|[;&|][[:space:]]*)npm[[:space:]]+run[[:space:]]+format([[:space:]:]|$)'; then
    _redirect "npm run format" "make fmt" "fmt"
  fi

  # npx <tool> — catch common tools invoked via npx
  if echo "$COMMAND" | grep -qE '(^|[;&|][[:space:]]*)npx[[:space:]]+eslint([[:space:]]|$)'; then
    _redirect "npx eslint" "make lint" "lint"
  fi
  if echo "$COMMAND" | grep -qE '(^|[;&|][[:space:]]*)npx[[:space:]]+jest([[:space:]]|$)'; then
    _redirect "npx jest" "make test" "test"
  fi
  if echo "$COMMAND" | grep -qE '(^|[;&|][[:space:]]*)npx[[:space:]]+vitest([[:space:]]|$)'; then
    _redirect "npx vitest" "make test" "test"
  fi
  if echo "$COMMAND" | grep -qE '(^|[;&|][[:space:]]*)npx[[:space:]]+tsc([[:space:]]|$)'; then
    _redirect "npx tsc" "make typecheck" "typecheck"
  fi
  if echo "$COMMAND" | grep -qE '(^|[;&|][[:space:]]*)npx[[:space:]]+biome([[:space:]]|$)'; then
    _redirect "npx biome" "make check" "check"
  fi

  exit 0
fi

# Helper: check if filename is a Makefile
_is_makefile() {
  local name="$1"
  case "$name" in
    Makefile|makefile|GNUmakefile) return 0 ;;
    *.mk) return 0 ;;
    *) return 1 ;;
  esac
}

# ── create tool ───────────────────────────────────────────────────────────────

if [ "$TOOL_NAME" = "create" ]; then
  FILE_PATH="$(echo "$TOOL_ARGS_RAW" | jq -r '.path // empty')"
  FILE_BASE="$(basename "$FILE_PATH")"

  if _is_makefile "$FILE_BASE"; then
    CONTENT="$(echo "$TOOL_ARGS_RAW" | jq -r '.file_text // empty')"
    _validate_makefile "$CONTENT"
  fi

  exit 0
fi

# ── edit tool ─────────────────────────────────────────────────────────────────

if [ "$TOOL_NAME" = "edit" ]; then
  FILE_PATH="$(echo "$TOOL_ARGS_RAW" | jq -r '.path // empty')"
  FILE_BASE="$(basename "$FILE_PATH")"

  if _is_makefile "$FILE_BASE"; then
    NEW_STR="$(echo "$TOOL_ARGS_RAW" | jq -r '.new_str // empty')"
    OLD_STR="$(echo "$TOOL_ARGS_RAW" | jq -r '.old_str // empty')"

    # Forbid adding @ in new recipe lines
    if echo "$NEW_STR" | grep -qP '^\t@'; then
      _deny "Adding '@' prefix to recipe lines is FORBIDDEN — '.SILENT:' already suppresses echoing. Remove the '@' prefix."
    fi

    # Forbid removing .SILENT: without replacing it
    if echo "$OLD_STR" | grep -q '^\.SILENT' && ! echo "$NEW_STR" | grep -q '^\.SILENT'; then
      _deny "Removing '.SILENT:' from the Makefile is FORBIDDEN — it is a required directive."
    fi

    # Forbid removing .ONESHELL: without replacing it
    if echo "$OLD_STR" | grep -q '\.ONESHELL' && ! echo "$NEW_STR" | grep -q '\.ONESHELL'; then
      _deny "Removing '.ONESHELL:' from the Makefile is FORBIDDEN — it is a required directive."
    fi

    # Full-state validation: deny edits to already-non-compliant Makefiles
    # unless the edit itself adds the missing directive
    _validate_existing_file "$FILE_PATH" "$NEW_STR"
  fi

  exit 0
fi

exit 0
