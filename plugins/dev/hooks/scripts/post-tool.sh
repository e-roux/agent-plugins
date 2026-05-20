#!/usr/bin/env bash
set -uo pipefail

INPUT="$(cat)"
TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.toolName // empty')"

# ── MCP git-ops circuit breaker: trip on MCP tool failure ──────────────────────
if [[ "$TOOL_NAME" == mcp__git-ops__* ]]; then
  RESULT_TYPE="$(printf '%s' "$INPUT" | jq -r '.toolResult.resultType // empty')"
  IS_ERROR="$(printf '%s' "$INPUT" | jq -r '.toolResult.isError // false')"
  RESULT="$(printf '%s' "$INPUT" | jq -r '.toolResult.textResultForLlm // .toolResult // empty')"
  if [[ "$RESULT_TYPE" == "error" ]] || [[ "$IS_ERROR" == "true" ]] || printf '%s' "$RESULT" | grep -qiE '(denied|failed|error|cannot)'; then
    date +%s > /tmp/.mcp-git-ops-cb 2>/dev/null || true
  fi
  exit 0
fi

[[ "$TOOL_NAME" == "bash" ]] || exit 0

RESULT="$(printf '%s' "$INPUT" | jq -r '.toolResult.textResultForLlm // .toolResult // empty')"
[[ -n "$RESULT" ]] || exit 0

CMD_INPUT="$(printf '%s' "$INPUT" | jq -r '.toolInput.command // empty' 2>/dev/null)"

REDACTED="$RESULT"
FOUND=0
ADDITIONAL_CTX=""

# GitHub PATs
if echo "$REDACTED" | grep -qE 'gh[ps]_[a-zA-Z0-9]{36}'; then
  REDACTED=$(echo "$REDACTED" | sed -E 's/gh[ps]_[a-zA-Z0-9]{36}/[REDACTED_GITHUB_TOKEN]/g')
  FOUND=1
fi

# GitHub OAuth tokens
if echo "$REDACTED" | grep -qE 'gho_[a-zA-Z0-9]{36}'; then
  REDACTED=$(echo "$REDACTED" | sed -E 's/gho_[a-zA-Z0-9]{36}/[REDACTED_GITHUB_OAUTH]/g')
  FOUND=1
fi

# AWS access keys
if echo "$REDACTED" | grep -qE 'AKIA[A-Z0-9]{16}'; then
  REDACTED=$(echo "$REDACTED" | sed -E 's/AKIA[A-Z0-9]{16}/[REDACTED_AWS_KEY]/g')
  FOUND=1
fi

# OpenAI API keys
if echo "$REDACTED" | grep -qE 'sk-[a-zA-Z0-9]{32,}'; then
  REDACTED=$(echo "$REDACTED" | sed -E 's/sk-[a-zA-Z0-9]{32,}/[REDACTED_API_KEY]/g')
  FOUND=1
fi

# Private keys
if echo "$REDACTED" | grep -q 'BEGIN.*PRIVATE KEY'; then
  REDACTED=$(echo "$REDACTED" | sed '/BEGIN.*PRIVATE KEY/,/END.*PRIVATE KEY/c\[REDACTED_PRIVATE_KEY]')
  FOUND=1
fi

# Generic long hex tokens (64+ chars)
if echo "$REDACTED" | grep -qE '[0-9a-f]{64}'; then
  REDACTED=$(echo "$REDACTED" | sed -E 's/[0-9a-f]{64,}/[REDACTED_TOKEN]/g')
  FOUND=1
fi

# ── release-reminder: after successful git tag, prompt for platform release ────
if [[ -n "$CMD_INPUT" ]] && printf '%s' "$CMD_INPUT" | grep -qE 'git[[:space:]]+tag\b.*v[0-9]'; then
  RESULT_TYPE="$(printf '%s' "$INPUT" | jq -r '.toolResult.resultType // empty' 2>/dev/null)"
  if [[ "$RESULT_TYPE" != "error" ]]; then
    TAG_VER=$(printf '%s' "$CMD_INPUT" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+([-.][a-zA-Z0-9]+)?' | head -1)
    TAG_REF="${TAG_VER:-<tag>}"
    ADDITIONAL_CTX="Tag ${TAG_REF} created locally. Next steps:
1. Push the tag: git push origin ${TAG_REF}
2. Build artifacts if applicable: make release
3. Create platform release: use mcp__git-ops__create_release (preferred) or gh/glab release create
   See the git-release skill resource for the complete workflow and capability-based enhancements."
  fi
fi

if [[ "$FOUND" -eq 1 ]] && [[ -n "$ADDITIONAL_CTX" ]]; then
  jq -n --arg result "$REDACTED" --arg ctx "$ADDITIONAL_CTX" \
    '{"modifiedResult":{"textResultForLlm":$result,"resultType":"success"},"additionalContext":$ctx}'
elif [[ "$FOUND" -eq 1 ]]; then
  jq -n --arg result "$REDACTED" \
    '{"modifiedResult":{"textResultForLlm":$result,"resultType":"success"},"additionalContext":"⚠️ Secrets were detected and redacted from tool output. Never include credentials in code or commit messages."}'
elif [[ -n "$ADDITIONAL_CTX" ]]; then
  jq -n --arg ctx "$ADDITIONAL_CTX" '{"additionalContext":$ctx}'
fi
