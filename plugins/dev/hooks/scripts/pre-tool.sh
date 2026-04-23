#!/usr/bin/env bash
set -uo pipefail

PLUGIN_ROOT="${COPILOT_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
LOG_DIR="$PLUGIN_ROOT/hooks/logs"

INPUT="$(cat)"
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // "."' 2>/dev/null) || CWD="."

deny() {
  local reason="$1"
  mkdir -p "$LOG_DIR" 2>/dev/null \
    && echo "denied at $(date -u +%Y-%m-%dT%H:%M:%SZ): $reason" >> "$LOG_DIR/pre-tool-denied.log" 2>/dev/null \
    || true
  jq -cn --arg reason "$reason" '{"permissionDecision":"deny","permissionDecisionReason":$reason}'
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

_is_on_protected_branch() {
  local branch="$1"
  [ "$branch" = "main" ] || [ "$branch" = "master" ]
}

_branch_first_deny() {
  local branch="$1"
  deny "Branch-first guard: you are on '$branch'. Create a feature branch first: git checkout -b <type>/<descriptive-slug>"
}

# ── _guard_one_call: apply all guards to a single tool invocation ─────────────
# ARGS must be a valid JSON object string (already unwrapped from double-encoding).
_guard_one_call() {
  local TOOL="$1"
  local ARGS="$2"
  local CMD="" FILE="" CONTENT=""

  case "$TOOL" in
    bash)
      CMD=$(printf '%s' "$ARGS" | jq -r '.command // ""' 2>/dev/null) || CMD=""
      ;;
    edit)
      FILE=$(printf '%s' "$ARGS" | jq -r '.path // ""' 2>/dev/null) || FILE=""
      CONTENT=$(printf '%s' "$ARGS" | jq -r '.new_str // ""' 2>/dev/null) || CONTENT=""
      ;;
    create)
      FILE=$(printf '%s' "$ARGS" | jq -r '.path // ""' 2>/dev/null) || FILE=""
      CONTENT=$(printf '%s' "$ARGS" | jq -r '.file_text // ""' 2>/dev/null) || CONTENT=""
      ;;
    *)
      return 0
      ;;
  esac

  # ── secrets-guard ────────────────────────────────────────────────────────────
  if [ "$TOOL" = "edit" ] || [ "$TOOL" = "create" ]; then
    if [ -n "$FILE" ] && ! _is_test_or_config "$FILE"; then
      SECRET_KEYS='(JWT_SECRET|API_KEY|CLIENT_SECRET|OIDC_CLIENT_SECRET|DB_PASS(WORD)?|MONGODB_URI|RABBITMQ_URL|PRIVATE_KEY|ACCESS_TOKEN_SECRET|SECRET_KEY|PASSWORD|PASSWD)'
      if printf '%s' "$CONTENT" | grep -qE "${SECRET_KEYS}[[:space:]]*:?=[[:space:]]*[\"'][^\"']{8,}[\"']"; then
        deny "Secrets guard: potential hardcoded credential detected in $(basename "$FILE"). Use os.Getenv() / process.env / env vars instead."
      fi
    fi
  fi

  # ── no-comments-guard ────────────────────────────────────────────────────────
  if [ "$TOOL" = "edit" ] || [ "$TOOL" = "create" ]; then
    if [ -n "$FILE" ] && ! _is_test_or_config "$FILE"; then
      FILE_EXT=$(printf '%s' "$FILE" | grep -oE '\.[^./]+$' || true)
      if printf '%s' "$FILE_EXT" | grep -qE '^\.(go|ts|tsx|js|jsx|py|rs|java|c|cpp|h|cs|rb|swift|kt)$'; then
        if printf '%s' "$CONTENT" | grep -qE '^[[:space:]]*(//|/\*|\*/)'; then
          deny "No-comments guard: code must be self-documenting — express intent through clear naming, not comment lines. See https://p.ampeco.com/infinite-engineer/infinite-engineer"
        fi
        if printf '%s' "$CONTENT" | grep -E '^[[:space:]]*#' | grep -qv '^[[:space:]]*#!'; then
          deny "No-comments guard: code must be self-documenting — express intent through clear naming, not comment lines. See https://p.ampeco.com/infinite-engineer/infinite-engineer"
        fi
      fi
    fi
  fi

  # ── branch-first-guard (edit/create) ─────────────────────────────────────────
  if [ "$TOOL" = "edit" ] || [ "$TOOL" = "create" ]; then
    if [ -n "$FILE" ]; then
      FILE_DIR=$(dirname "$FILE")
      [ -d "$FILE_DIR" ] || FILE_DIR="$CWD"
      BRANCH=$(_current_branch_for_path "$FILE_DIR")
      if _is_on_protected_branch "$BRANCH"; then
        _branch_first_deny "$BRANCH"
      fi
    fi
  fi

  [ "$TOOL" = "bash" ] || return 0
  [ -z "$CMD" ] && return 0

  # ── branch-first-guard (bash): block shell-level file writes on main ──────────
  if printf '%s' "$CMD" | grep -qE '(>[[:space:]]+[^/dev]|>>[[:space:]]+[^/dev]|[[:space:]]tee[[:space:]][^-]|sed[[:space:]]+-[^ ]*i)'; then
    BASH_BRANCH=$(_current_branch_for_path "$CWD")
    if _is_on_protected_branch "$BASH_BRANCH"; then
      _branch_first_deny "$BASH_BRANCH"
    fi
  fi

  # ── migration-guard ───────────────────────────────────────────────────────────
  if printf '%s' "$CMD" | grep -qiE '(migrations?/|\.sql)'; then
    if printf '%s' "$CMD" | grep -qiE '(DROP[[:space:]]+(TABLE|COLUMN|SCHEMA)|TRUNCATE[[:space:]]+TABLE|DELETE[[:space:]]+FROM)'; then
      deny "Migration guard: destructive SQL (DROP/TRUNCATE/DELETE) is forbidden in migrations. Use additive changes only (ADD COLUMN, CREATE TABLE)."
    fi
  fi

  # ── branch-guard: push/merge to main directly, --no-verify ───────────────────
  if printf '%s' "$CMD" | grep -qE 'git[[:space:]]+(push|merge)[[:space:]][^&|;]*\bmain\b'; then
    deny "Branch guard: never push/merge to main directly. Use a PR: gh pr create --base <default-branch>."
  fi
  if printf '%s' "$CMD" | grep -qE 'git[[:space:]]+commit[[:space:]]+.*--no-verify'; then
    deny "Branch guard: --no-verify bypasses commit hooks. Remove the flag."
  fi
}

# ── Dispatch: preToolUse delivers a toolCalls array ──────────────────────────
# Each entry: {id, name, args} where args is a double-encoded JSON string.
# jq -r unwraps the string encoding, yielding a plain JSON object.
TOOL_CALLS=$(printf '%s' "$INPUT" | jq -c '.toolCalls // empty' 2>/dev/null) || TOOL_CALLS=""

if [ -n "$TOOL_CALLS" ] && [ "$TOOL_CALLS" != "null" ] && [ "$TOOL_CALLS" != "[]" ]; then
  CALL_COUNT=$(printf '%s' "$TOOL_CALLS" | jq 'length' 2>/dev/null) || CALL_COUNT=0
  i=0
  while [ "$i" -lt "$CALL_COUNT" ]; do
    TOOL=$(printf '%s' "$TOOL_CALLS" | jq -r ".[$i].name // \"\"" 2>/dev/null) || TOOL=""
    ARGS=$(printf '%s' "$TOOL_CALLS" | jq -r ".[$i].args // \"{}\"" 2>/dev/null) || ARGS="{}"
    _guard_one_call "$TOOL" "$ARGS"
    i=$((i + 1))
  done
fi

exit 0
