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

_redirect() {
  local original="$1" replacement="$2" target="$3"
  mkdir -p "$LOG_DIR" 2>/dev/null \
    && echo "redirected at $(date -u +%Y-%m-%dT%H:%M:%SZ): $original -> $replacement" >> "$LOG_DIR/pre-tool-denied.log" 2>/dev/null \
    || true
  jq -n --arg cmd "$replacement" --arg ctx "Redirected \`$original\` -> \`$replacement\`. Always use make targets (\`make $target\`) - never call tools directly." \
    '{"modifiedArgs":{"command":$cmd},"additionalContext":$ctx}'
  exit 0
}

_mcp_git_ops_available() {
  command -v mcp-git-ops >/dev/null 2>&1 || return 1
  [ -f "/tmp/.mcp-git-ops-cb" ] || return 0
  local now tripped age
  now=$(date +%s)
  tripped=$(cat "/tmp/.mcp-git-ops-cb" 2>/dev/null || echo 0)
  age=$((now - tripped))
  [ "$age" -lt 300 ] && return 1
  rm -f "/tmp/.mcp-git-ops-cb" 2>/dev/null
  return 0
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

_is_makefile() {
  local name="$1"
  case "$name" in
    Makefile|makefile|GNUmakefile) return 0 ;;
    *.mk) return 0 ;;
    *) return 1 ;;
  esac
}

_validate_makefile() {
  local content="$1"

  if ! printf '%s' "$content" | grep -q '^\.SILENT'; then
    deny "Makefile missing required directive: '.SILENT:' - add it before the first target to suppress recipe echoing without @."
  fi

  if ! printf '%s' "$content" | grep -q '\.ONESHELL'; then
    deny "Makefile missing required directive: '.ONESHELL:' - add it to run each recipe in a single shell instance."
  fi

  if ! printf '%s' "$content" | grep -q '\.DEFAULT_GOAL'; then
    deny "Makefile missing required directive: '.DEFAULT_GOAL := help' - the default target must be 'help'."
  fi

  if printf '%s' "$content" | grep -qP '^\t@'; then
    deny "Makefile has '@' prefix in recipe lines - this is redundant with '.SILENT:' and FORBIDDEN. Remove all '@' prefixes from recipes."
  fi

  if printf '%s' "$content" | grep -qP '^[a-zA-Z_.][a-zA-Z_.0-9]*[^#\n]*##'; then
    deny "Makefile has '##' inline annotations on target lines - Approach B (grep-parsed help) is FORBIDDEN. Use explicit printf entries in the help target instead (Approach A)."
  fi

  if ! printf '%s' "$content" | grep -qP '(?:^\.PHONY:[^\n]*\bqa\b|^qa\s*:)'; then
    deny "Makefile missing required 'qa' target - add a 'qa:' recipe that runs 'check test' as the quality gate (e.g., 'qa: check test')."
  fi
}

_validate_existing_makefile() {
  local filepath="$1" new_str="$2"

  [ -f "$filepath" ] || return 0
  local current
  current="$(cat "$filepath")"

  if ! printf '%s' "$current" | grep -q '^\.SILENT' && ! printf '%s' "$new_str" | grep -q '\.SILENT'; then
    deny "Makefile at $filepath is missing '.SILENT:' - add this directive before making other edits."
  fi

  if ! printf '%s' "$current" | grep -q '\.ONESHELL' && ! printf '%s' "$new_str" | grep -q '\.ONESHELL'; then
    deny "Makefile at $filepath is missing '.ONESHELL:' - add this directive before making other edits."
  fi

  if ! printf '%s' "$current" | grep -q '\.DEFAULT_GOAL' && ! printf '%s' "$new_str" | grep -q '\.DEFAULT_GOAL'; then
    deny "Makefile at $filepath is missing '.DEFAULT_GOAL' - add this directive before making other edits."
  fi
}

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

  if [ "$TOOL" = "edit" ] || [ "$TOOL" = "create" ]; then
    if [ -n "$FILE" ]; then
      local base_name
      base_name="$(basename "$FILE")"
      if _is_makefile "$base_name" && ! printf '%s' "$FILE" | grep -qE '(/tmp/|/private/tmp/|/var/folders/)'; then
        if [ "$TOOL" = "create" ]; then
          _validate_makefile "$CONTENT"
        else
          local old_str
          old_str=$(printf '%s' "$ARGS" | jq -r '.old_str // ""' 2>/dev/null)
          if printf '%s' "$CONTENT" | grep -qP '^\t@'; then
            deny "Adding '@' prefix to recipe lines is FORBIDDEN - '.SILENT:' already suppresses echoing. Remove the '@' prefix."
          fi
          if printf '%s' "$old_str" | grep -q '^\.SILENT' && ! printf '%s' "$CONTENT" | grep -q '^\.SILENT'; then
            deny "Removing '.SILENT:' from the Makefile is FORBIDDEN - it is a required directive."
          fi
          if printf '%s' "$old_str" | grep -q '\.ONESHELL' && ! printf '%s' "$CONTENT" | grep -q '\.ONESHELL'; then
            deny "Removing '.ONESHELL:' from the Makefile is FORBIDDEN - it is a required directive."
          fi
          _validate_existing_makefile "$FILE" "$CONTENT"
        fi
      fi
    fi
  fi

  if [ "$TOOL" = "edit" ] || [ "$TOOL" = "create" ]; then
    if [ -n "$FILE" ] && ! _is_test_or_config "$FILE"; then
      local secret_keys
      secret_keys='(JWT_SECRET|API_KEY|CLIENT_SECRET|OIDC_CLIENT_SECRET|DB_PASS(WORD)?|MONGODB_URI|RABBITMQ_URL|PRIVATE_KEY|ACCESS_TOKEN_SECRET|SECRET_KEY|PASSWORD|PASSWD)'
      if printf '%s' "$CONTENT" | grep -qE "${secret_keys}[[:space:]]*:?=[[:space:]]*[\"'][^\"']{8,}[\"']"; then
        deny "Secrets guard: potential hardcoded credential detected in $(basename "$FILE"). Use os.Getenv() / process.env / env vars instead."
      fi
    fi
  fi

  if [ "$TOOL" = "edit" ] || [ "$TOOL" = "create" ]; then
    if [ -n "$FILE" ] && ! _is_test_or_config "$FILE"; then
      local file_ext
      file_ext=$(printf '%s' "$FILE" | grep -oE '\.[^./]+$' || true)
      if printf '%s' "$file_ext" | grep -qE '^\.(go|ts|tsx|js|jsx|py|rs|java|c|cpp|h|cs|rb|swift|kt)$'; then
        if printf '%s' "$CONTENT" | grep -qE '^[[:space:]]*(//|/\*|\*/)'; then
          deny "No-comments guard: code must be self-documenting - express intent through clear naming, not comment lines. See https://p.ampeco.com/infinite-engineer/infinite-engineer"
        fi
        local stripped
        stripped=$(printf '%s' "$CONTENT" | awk '/^[[:space:]]*# \/\/\// { skip=!skip; next } skip { next } 1')
        if printf '%s' "$stripped" | grep -E '^[[:space:]]*#' | grep -qvE '^[[:space:]]*(#!|# noqa)'; then
          deny "No-comments guard: code must be self-documenting - express intent through clear naming, not comment lines. See https://p.ampeco.com/infinite-engineer/infinite-engineer"
        fi
      fi
    fi
  fi

  if [ "$TOOL" = "edit" ] || [ "$TOOL" = "create" ]; then
    if [ -n "$FILE" ] && ! _is_test_or_config "$FILE"; then
      local file_dir
      file_dir=$(dirname "$FILE")
      [ -d "$file_dir" ] || file_dir="$CWD"
      local branch
      branch=$(_current_branch_for_path "$file_dir")
      if _is_on_protected_branch "$branch"; then
        _branch_first_deny "$branch"
      fi
    fi
  fi

  [ "$TOOL" = "bash" ] || return 0
  [ -z "$CMD" ] && return 0

  local matches_cmd
  matches_cmd() { printf '%s' "$CMD" | grep -qE "(^|[;&|][[:space:]]*)$1([[:space:]]|\$)"; }

  if matches_cmd "pytest"; then
    _redirect "pytest" "make test" "test"
  fi
  if printf '%s' "$CMD" | grep -qE '(^|[;&|][[:space:]]*)ruff[[:space:]]+format([[:space:]]|\$)'; then
    _redirect "ruff format" "make fmt" "fmt"
  fi
  if printf '%s' "$CMD" | grep -qE '(^|[;&|][[:space:]]*)ruff[[:space:]]+check([[:space:]]|\$)'; then
    _redirect "ruff check" "make lint" "lint"
  fi
  if printf '%s' "$CMD" | grep -qE '(^|[;&|][[:space:]]*)go[[:space:]]+test([[:space:]]|\$)'; then
    _redirect "go test" "make test" "test"
  fi
  if printf '%s' "$CMD" | grep -qE '(^|[;&|][[:space:]]*)go[[:space:]]+build([[:space:]]|\$)'; then
    _redirect "go build" "make build" "build"
  fi
  if matches_cmd "golangci-lint"; then
    _redirect "golangci-lint" "make lint" "lint"
  fi
  if matches_cmd "eslint"; then
    _redirect "eslint" "make lint" "lint"
  fi
  if printf '%s' "$CMD" | grep -qE '(^|[;&|][[:space:]]*)biome[[:space:]]+format([[:space:]]|\$)'; then
    _redirect "biome format" "make fmt" "fmt"
  fi
  if printf '%s' "$CMD" | grep -qE '(^|[;&|][[:space:]]*)biome[[:space:]]+lint([[:space:]]|\$)'; then
    _redirect "biome lint" "make lint" "lint"
  fi
  if printf '%s' "$CMD" | grep -qE '(^|[;&|][[:space:]]*)biome[[:space:]]+check([[:space:]]|\$)'; then
    _redirect "biome check" "make check" "check"
  fi
  if matches_cmd "jest"; then
    _redirect "jest" "make test" "test"
  fi
  if matches_cmd "vitest"; then
    _redirect "vitest" "make test" "test"
  fi
  if printf '%s' "$CMD" | grep -qE '(^|[;&|][[:space:]]*)bun[[:space:]]+test([[:space:]]|\$)'; then
    _redirect "bun test" "make test" "test"
  fi
  if matches_cmd "black"; then
    _redirect "black" "make fmt" "fmt"
  fi
  local forbidden_py
  forbidden_py='(^|[;&|][[:space:]]*)(python3?|pip3?|virtualenv)([[:space:]]|\$)'
  if printf '%s' "$CMD" | grep -qE "$forbidden_py"; then
    deny "Direct python/pip/virtualenv is forbidden. Use uv: uv run <script>, uv add <pkg>, uvx <tool>"
  fi
  if printf '%s' "$CMD" | grep -qE '(^|[;&|][[:space:]]*)mypy([[:space:]]|\$)'; then
    _redirect "mypy" "make typecheck" "typecheck"
  fi
  if printf '%s' "$CMD" | grep -qE '(^|[;&|][[:space:]]*)tsc([[:space:]]|\$)'; then
    _redirect "tsc" "make typecheck" "typecheck"
  fi
  if matches_cmd "svelte-check" || printf '%s' "$CMD" | grep -qE '(^|[;&|][[:space:]]*)npx[[:space:]]+svelte-check([[:space:]]|\$)'; then
    _redirect "svelte-check" "make typecheck" "typecheck"
  fi
  if printf '%s' "$CMD" | grep -qE '(^|[;&|][[:space:]]*)npm[[:space:]]+run[[:space:]]+test([[:space:]]|\$)'; then
    _redirect "npm run test" "make test" "test"
  fi
  if printf '%s' "$CMD" | grep -qE '(^|[;&|][[:space:]]*)npm[[:space:]]+test([[:space:]]|\$)'; then
    _redirect "npm test" "make test" "test"
  fi
  if printf '%s' "$CMD" | grep -qE '(^|[;&|][[:space:]]*)npm[[:space:]]+run[[:space:]]+check([[:space:]]|\$)'; then
    _redirect "npm run check" "make check" "check"
  fi
  if printf '%s' "$CMD" | grep -qE '(^|[;&|][[:space:]]*)npm[[:space:]]+run[[:space:]]+lint([[:space:]]|\$)'; then
    _redirect "npm run lint" "make lint" "lint"
  fi
  if printf '%s' "$CMD" | grep -qE '(^|[;&|][[:space:]]*)npm[[:space:]]+run[[:space:]]+build([[:space:]]|\$)'; then
    _redirect "npm run build" "make build" "build"
  fi
  if printf '%s' "$CMD" | grep -qE '(^|[;&|][[:space:]]*)npm[[:space:]]+run[[:space:]]+dev([[:space:]]|\$)'; then
    _redirect "npm run dev" "make dev" "dev"
  fi
  if printf '%s' "$CMD" | grep -qE '(^|[;&|][[:space:]]*)npm[[:space:]]+run[[:space:]]+format([[:space:]:]|\$)'; then
    _redirect "npm run format" "make fmt" "fmt"
  fi
  if printf '%s' "$CMD" | grep -qE '(^|[;&|][[:space:]]*)npx[[:space:]]+eslint([[:space:]]|\$)'; then
    _redirect "npx eslint" "make lint" "lint"
  fi
  if printf '%s' "$CMD" | grep -qE '(^|[;&|][[:space:]]*)npx[[:space:]]+jest([[:space:]]|\$)'; then
    _redirect "npx jest" "make test" "test"
  fi
  if printf '%s' "$CMD" | grep -qE '(^|[;&|][[:space:]]*)npx[[:space:]]+vitest([[:space:]]|\$)'; then
    _redirect "npx vitest" "make test" "test"
  fi
  if printf '%s' "$CMD" | grep -qE '(^|[;&|][[:space:]]*)npx[[:space:]]+tsc([[:space:]]|\$)'; then
    _redirect "npx tsc" "make typecheck" "typecheck"
  fi
  if printf '%s' "$CMD" | grep -qE '(^|[;&|][[:space:]]*)npx[[:space:]]+biome([[:space:]]|\$)'; then
    _redirect "npx biome" "make check" "check"
  fi

  if printf '%s' "$CMD" | grep -qE 'git\s+push\b'; then
    if _mcp_git_ops_available; then
      deny "Use the mcp__git-ops__push tool instead of bash git push. It enforces branch protection and triggers CI monitoring. If MCP failed previously, retry in a moment - the circuit breaker will allow bash through."
    fi
  fi
  if printf '%s' "$CMD" | grep -qE '(gh\s+pr\s+create|glab\s+mr\s+create|az\s+repos\s+pr\s+create)\b'; then
    if _mcp_git_ops_available; then
      deny "Use the mcp__git-ops__create_pr tool instead. It auto-detects the platform and enforces branch protection."
    fi
  fi
  if printf '%s' "$CMD" | grep -qE '(gh\s+pr\s+merge|glab\s+mr\s+merge|az\s+repos\s+pr\s+update.*--status\s+completed)\b'; then
    if _mcp_git_ops_available; then
      deny "Use the mcp__git-ops__merge_pr tool instead. It auto-detects the platform."
    fi
  fi

  if printf '%s' "$CMD" | grep -qE '(>[[:space:]]+[^/dev]|>>[[:space:]]+[^/dev]|[[:space:]]tee[[:space:]][^-]|sed[[:space:]]+-[^ ]*i)'; then
    local bash_branch
    bash_branch=$(_current_branch_for_path "$CWD")
    if _is_on_protected_branch "$bash_branch"; then
      _branch_first_deny "$bash_branch"
    fi
  fi

  if printf '%s' "$CMD" | grep -qiE '(migrations?/|\.sql)'; then
    if printf '%s' "$CMD" | grep -qiE '(DROP[[:space:]]+(TABLE|COLUMN|SCHEMA)|TRUNCATE[[:space:]]+TABLE|DELETE[[:space:]]+FROM)'; then
      deny "Migration guard: destructive SQL (DROP/TRUNCATE/DELETE) is forbidden in migrations. Use additive changes only (ADD COLUMN, CREATE TABLE)."
    fi
  fi

  if printf '%s' "$CMD" | grep -qE 'git[[:space:]]+tag\b'; then
    local version raw_version plugin
    raw_version=$(printf '%s' "$CMD" | grep -oE '([a-zA-Z0-9_-]+/)?v[0-9]+\.[0-9]+\.[0-9]+([-.][a-zA-Z0-9]+)?' | head -1)
    if [ -n "$raw_version" ]; then
      version=$(printf '%s' "$raw_version" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+([-.][a-zA-Z0-9]+)?' | head -1)
      plugin=$(printf '%s' "$raw_version" | grep -oE '^[^/]+' | grep -v 'v[0-9]' || true)
      local changelog="$CWD/CHANGELOG.md"
      if [ -n "$plugin" ] && [ -f "$CWD/plugins/$plugin/CHANGELOG.md" ]; then
        changelog="$CWD/plugins/$plugin/CHANGELOG.md"
      fi
      if [ ! -f "$changelog" ]; then
        deny "Changelog guard: CHANGELOG.md not found for plugin '$plugin' - create it with an [Unreleased] section via a release PR before tagging."
      fi
      if ! grep -qE "^## \[${version}\]|^## \[${version#v}\]" "$changelog" 2>/dev/null; then
        deny "Changelog guard: ${version} not found as a heading in changelog: $changelog - update it with a [${version}] section via a release PR before tagging."
      fi
    fi
  fi

  if printf '%s' "$CMD" | grep -qE 'git[[:space:]]+commit\b'; then
    if [ -f "$CWD/Makefile" ]; then
      local qa_out qa_status
      qa_out=$(make -C "$CWD" qa 2>&1)
      qa_status=$?
      if [ $qa_status -ne 0 ]; then
        deny "QA gate: make qa failed - fix ALL errors before committing. Zero failures required, regardless of error origin.\n\n${qa_out}"
      fi
      jq -cn --arg ctx "QA gate passed. Output:\n\`\`\`\n${qa_out}\n\`\`\`\n\nWarnings MUST be fixed when feasible - do not ignore them." \
        '{"additionalContext":$ctx}'
      exit 0
    fi
  fi

  if printf '%s' "$CMD" | grep -qE 'git[[:space:]]+(push|merge)[[:space:]][^&|;]*\bmain\b'; then
    deny "Branch guard: never push/merge to main directly. Use a PR: gh pr create --base <default-branch>."
  fi
  if printf '%s' "$CMD" | grep -qE 'git[[:space:]]+commit[[:space:]]+.*--no-verify'; then
    deny "Branch guard: --no-verify bypasses commit hooks. Remove the flag."
  fi
}

TOOL_CALLS=$(printf '%s' "$INPUT" | jq -c '.toolCalls // empty' 2>/dev/null) || TOOL_CALLS=""

if [ -n "$TOOL_CALLS" ] && [ "$TOOL_CALLS" != "null" ] && [ "$TOOL_CALLS" != "[]" ]; then
  CALL_COUNT=$(printf '%s' "$TOOL_CALLS" | jq 'length' 2>/dev/null) || CALL_COUNT=0
  i=0
  while [ "$i" -lt "$CALL_COUNT" ]; do
    TOOL=$(printf '%s' "$TOOL_CALLS" | jq -r --argjson idx "$i" '.[$idx].name // ""' 2>/dev/null) || TOOL=""
    ARGS=$(printf '%s' "$TOOL_CALLS" | jq -r --argjson idx "$i" '.[$idx].args // "{}"' 2>/dev/null) || ARGS="{}"
    _guard_one_call "$TOOL" "$ARGS"
    i=$((i + 1))
  done
fi

exit 0
