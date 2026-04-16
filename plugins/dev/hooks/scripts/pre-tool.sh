#!/usr/bin/env bash
set -uo pipefail

PLUGIN_ROOT="${COPILOT_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
LOG_DIR="$PLUGIN_ROOT/hooks/logs"

INPUT="$(cat)"
TOOL=$(printf '%s' "$INPUT" | jq -r '.toolName' 2>/dev/null) || exit 0
ARGS=$(printf '%s' "$INPUT" | jq -r '.toolArgs' 2>/dev/null) || ARGS="{}"
CMD=""
FILE=""
CONTENT=""

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
esac

deny() {
  local reason="$1"
  mkdir -p "$LOG_DIR" 2>/dev/null \
    && echo "denied at $(date -u +%Y-%m-%dT%H:%M:%SZ): $reason" >> "$LOG_DIR/pre-tool-denied.log" 2>/dev/null \
    || true
  jq -cn --arg reason "$reason" '{"permissionDecision":"deny","permissionDecisionReason":$reason}'
  exit 0
}

_is_test_or_config() {
  printf '%s' "$1" | grep -qE '(_test\.(go|ts|js|rs|py)|\.test\.(ts|js)|spec\.(ts|js)|\.example|\.md|\.template|testdata)'
}

# ── secrets-guard: block hardcoded credentials in source files ────────────────
if [ "$TOOL" = "edit" ] || [ "$TOOL" = "create" ]; then
  if [ -n "$FILE" ] && ! _is_test_or_config "$FILE"; then
    SECRET_KEYS='(JWT_SECRET|API_KEY|CLIENT_SECRET|OIDC_CLIENT_SECRET|DB_PASS(WORD)?|MONGODB_URI|RABBITMQ_URL|PRIVATE_KEY|ACCESS_TOKEN_SECRET|SECRET_KEY|PASSWORD|PASSWD)'
    if printf '%s' "$CONTENT" | grep -qE "${SECRET_KEYS}[[:space:]]*:?=[[:space:]]*[\"'][^\"']{8,}[\"']"; then
      deny "Secrets guard: potential hardcoded credential detected in $(basename "$FILE"). Use os.Getenv() / process.env / env vars instead."
    fi
  fi
fi

# ── no-comments-guard: code must be self-documenting ─────────────────────────
# Applies to code files only. Skips tests, configs, scripts, and markdown.
# Rationale: comments can conflict with code, confusing the LLM about which to follow.
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

[ "$TOOL" = "bash" ] || exit 0
[ -z "$CMD" ] && exit 0

# ── migration-guard: block destructive SQL in migration files ─────────────────
if printf '%s' "$CMD" | grep -qiE '(migrations?/|\.sql)'; then
  if printf '%s' "$CMD" | grep -qiE '(DROP[[:space:]]+(TABLE|COLUMN|SCHEMA)|TRUNCATE[[:space:]]+TABLE|DELETE[[:space:]]+FROM)'; then
    deny "Migration guard: destructive SQL (DROP/TRUNCATE/DELETE) is forbidden in migrations. Use additive changes only (ADD COLUMN, CREATE TABLE)."
  fi
fi

# ── branch-guard: block direct main push/merge and --no-verify ───────────────
if printf '%s' "$CMD" | grep -qE 'git[[:space:]]+(push|merge)[[:space:]][^&|;]*\bmain\b'; then
  deny "Branch guard: never push/merge to main directly. Use a PR: gh pr create --base <default-branch>."
fi
if printf '%s' "$CMD" | grep -qE 'git[[:space:]]+commit[[:space:]]+.*--no-verify'; then
  deny "Branch guard: --no-verify bypasses commit hooks. Remove the flag."
fi

exit 0
