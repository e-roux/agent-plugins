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

_is_test_or_config() {
  printf '%s' "$1" | grep -qE '(_test\.(go|ts|js|rs|py)|\.test\.(ts|js)|spec\.(ts|js)|\.example|\.md|\.template|testdata|\.bats|/test/)'
}

_current_branch_for_path() {
  local dir="$1"
  local branch
  branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
  local rc=$?
  if [ $rc -ne 0 ] || [ "$branch" = "HEAD" ]; then
    git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || true
  else
    printf '%s' "$branch"
  fi
}

_is_protected_branch() {
  [ "$1" = "main" ] || [ "$1" = "master" ]
}

_guard_file() {
  local FILE="$1" CONTENT="$2"
  [ -n "$FILE" ] || return 0
  _is_test_or_config "$FILE" && return 0

  FILE_EXT=$(printf '%s' "$FILE" | grep -oE '\.[^./]+$' || true)

  SECRET_KEYS='(JWT_SECRET|API_KEY|CLIENT_SECRET|OIDC_CLIENT_SECRET|DB_PASS(WORD)?|MONGODB_URI|RABBITMQ_URL|PRIVATE_KEY|ACCESS_TOKEN_SECRET|SECRET_KEY|PASSWORD|PASSWD)'
  if printf '%s' "$CONTENT" | grep -qE "${SECRET_KEYS}[[:space:]]*:?=[[:space:]]*[\"'][^\"']{8,}[\"']"; then
    deny "Secrets guard: potential hardcoded credential detected in $(basename "$FILE"). Use env vars (os.Getenv / process.env) instead."
  fi

  if printf '%s' "$FILE_EXT" | grep -qE '^\.(go|ts|tsx|js|jsx|py|rs|java|c|cpp|h|cs|rb|swift|kt)$'; then
    if printf '%s' "$CONTENT" | grep -qE '^[[:space:]]*(//|/\*|\*/)'; then
      deny "No-comments guard: code must be self-documenting — no comment lines in $(basename "$FILE"). Express intent through clear naming."
    fi
    STRIPPED=$(printf '%s' "$CONTENT" | awk '/^[[:space:]]*# \/\/\// { skip=!skip; next } skip { next } 1')
    if printf '%s' "$STRIPPED" | grep -E '^[[:space:]]*#' | grep -qvE '^[[:space:]]*(#!|# noqa)'; then
      deny "No-comments guard: code must be self-documenting — no comment lines in $(basename "$FILE")."
    fi
  fi

  FILE_DIR=$(dirname "$FILE")
  [ -d "$FILE_DIR" ] || FILE_DIR="$CWD"
  BRANCH=$(_current_branch_for_path "$FILE_DIR")
  if _is_protected_branch "$BRANCH"; then
    deny "Branch-first guard: you are on '$BRANCH'. Create a feature branch first: git checkout -b <type>/<slug>"
  fi
}

_guard_shell() {
  local CMD="$1"
  [ -n "$CMD" ] || return 0

  if printf '%s' "$CMD" | grep -qE '(>[[:space:]]+[^/dev]|>>[[:space:]]+[^/dev]|[[:space:]]tee[[:space:]][^-]|sed[[:space:]]+-[^ ]*i)'; then
    BASH_BRANCH=$(_current_branch_for_path "$CWD")
    if _is_protected_branch "$BASH_BRANCH"; then
      deny "Branch-first guard: you are on '$BASH_BRANCH'. Create a feature branch first: git checkout -b <type>/<slug>"
    fi
  fi

  if printf '%s' "$CMD" | grep -qiE '(migrations?/|\.sql)'; then
    if printf '%s' "$CMD" | grep -qiE '(DROP[[:space:]]+(TABLE|COLUMN|SCHEMA)|TRUNCATE[[:space:]]+TABLE|DELETE[[:space:]]+FROM)'; then
      deny "Migration guard: destructive SQL (DROP/TRUNCATE/DELETE) is forbidden in migrations. Use additive changes only."
    fi
  fi

  if printf '%s' "$CMD" | grep -qE 'git[[:space:]]+commit\b'; then
    if [ -f "$CWD/Makefile" ]; then
      QA_OUT=$(make -C "$CWD" qa 2>&1)
      QA_STATUS=$?
      if [ $QA_STATUS -ne 0 ]; then
        deny "QA gate: make qa failed — fix ALL errors before committing. Zero failures required.\n\n${QA_OUT}"
      fi
    fi
  fi

  if printf '%s' "$CMD" | grep -qE 'git[[:space:]]+(push|merge)[[:space:]][^&|;]*\bmain\b'; then
    deny "Branch guard: never push/merge to main directly. Use a PR: gh pr create --base main"
  fi

  if printf '%s' "$CMD" | grep -qE 'git[[:space:]]+commit[[:space:]]+.*--no-verify'; then
    deny "Branch guard: --no-verify bypasses commit hooks. Remove the flag."
  fi
}

case "$TOOL_NAME" in
  write_file|Write|create)
    FILE=$(printf '%s' "$TOOL_INPUT" | jq -r '.file_path // .path // ""' 2>/dev/null) || FILE=""
    CONTENT=$(printf '%s' "$TOOL_INPUT" | jq -r '.content // .file_text // ""' 2>/dev/null) || CONTENT=""
    _guard_file "$FILE" "$CONTENT"
    ;;
  replace|Edit|edit)
    FILE=$(printf '%s' "$TOOL_INPUT" | jq -r '.file_path // .path // ""' 2>/dev/null) || FILE=""
    CONTENT=$(printf '%s' "$TOOL_INPUT" | jq -r '.new_string // .new_str // ""' 2>/dev/null) || CONTENT=""
    _guard_file "$FILE" "$CONTENT"
    ;;
  run_shell_command|Bash|bash)
    CMD=$(printf '%s' "$TOOL_INPUT" | jq -r '.command // ""' 2>/dev/null) || CMD=""
    _guard_shell "$CMD"
    ;;
esac

exit 0
