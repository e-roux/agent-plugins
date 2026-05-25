#!/usr/bin/env bash
set -uo pipefail

PLUGIN_ROOT="${extensionPath:-$(cd "$(dirname "$0")/../.." && pwd)}"
LOG_DIR="$PLUGIN_ROOT/hooks/logs"

INPUT="$(cat)"
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null) || TOOL_NAME=""
TOOL_INPUT=$(printf '%s' "$INPUT" | jq -c '.tool_input // {}' 2>/dev/null) || TOOL_INPUT="{}"
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // "."' 2>/dev/null) || CWD="."

deny() {
  local reason="$1"
  mkdir -p "$LOG_DIR" 2>/dev/null \
    && echo "denied at $(date -u +%Y-%m-%dT%H:%M:%SZ): $reason" >> "$LOG_DIR/gemini-pre-tool-denied.log" 2>/dev/null \
    || true
  jq -cn --arg reason "$reason" '{"decision":"deny","reason":$reason}'
  exit 0
}

_validate_makefile_content() {
  local content="$1"

  printf '%s' "$content" | grep -q '^\.SILENT' \
    || deny "Makefile missing required directive: '.SILENT:' — add it before the first target."

  printf '%s' "$content" | grep -q '\.ONESHELL' \
    || deny "Makefile missing required directive: '.ONESHELL:' — add it to run each recipe in a single shell instance."

  printf '%s' "$content" | grep -q '\.DEFAULT_GOAL' \
    || deny "Makefile missing required directive: '.DEFAULT_GOAL := help' — the default target must be 'help'."

  printf '%s' "$content" | grep -P '^\t@' 2>/dev/null \
    && deny "Makefile has '@' prefix on recipe lines — redundant with '.SILENT:' and FORBIDDEN. Remove all '@' prefixes."

  if ! printf '%s' "$content" | grep -qE '^qa[[:space:]]*:'; then
    printf '%s' "$content" | grep -qE '\.PHONY.*\bqa\b' \
      || deny "Makefile is missing a 'qa' target — it is MANDATORY. Add 'qa: fmt lint typecheck test' (or similar)."
  fi
}

_check_direct_tool_invocation() {
  local CMD="$1"
  DIRECT_TOOLS='(^|[[:space:]|;&])(pytest|ruff[[:space:]]+(format|check)|go[[:space:]]+(test|build)|golangci-lint|eslint|jest|bun[[:space:]]+test|black|mypy|tox|cargo[[:space:]]+(test|build|clippy))'
  if printf '%s' "$CMD" | grep -qE "$DIRECT_TOOLS"; then
    deny "Make-first guard: use 'make <target>' instead of running tools directly. Run 'make help' to see available targets."
  fi
}

case "$TOOL_NAME" in
  write_file|Write|create)
    FILE=$(printf '%s' "$TOOL_INPUT" | jq -r '.file_path // .path // ""' 2>/dev/null) || FILE=""
    CONTENT=$(printf '%s' "$TOOL_INPUT" | jq -r '.content // .file_text // ""' 2>/dev/null) || CONTENT=""
    BASENAME=$(basename "$FILE")
    case "$BASENAME" in
      Makefile|makefile|GNUmakefile)
        _validate_makefile_content "$CONTENT"
        ;;
    esac
    ;;
  replace|Edit|edit)
    FILE=$(printf '%s' "$TOOL_INPUT" | jq -r '.file_path // .path // ""' 2>/dev/null) || FILE=""
    CONTENT=$(printf '%s' "$TOOL_INPUT" | jq -r '.new_string // .new_str // ""' 2>/dev/null) || CONTENT=""
    BASENAME=$(basename "$FILE")
    case "$BASENAME" in
      Makefile|makefile|GNUmakefile)
        _validate_makefile_content "$CONTENT"
        ;;
    esac
    ;;
  run_shell_command|Bash|bash)
    CMD=$(printf '%s' "$TOOL_INPUT" | jq -r '.command // ""' 2>/dev/null) || CMD=""
    [ -n "$CMD" ] || exit 0
    _check_direct_tool_invocation "$CMD"
    ;;
esac

exit 0
