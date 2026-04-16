#!/usr/bin/env bash
set -uo pipefail

INPUT="$(cat)"
TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.toolName // empty')"

# Only scan bash tool output for secrets
[[ "$TOOL_NAME" == "bash" ]] || exit 0

RESULT="$(printf '%s' "$INPUT" | jq -r '.toolResult.textResultForLlm // .toolResult // empty')"
[[ -n "$RESULT" ]] || exit 0

REDACTED="$RESULT"
FOUND=0

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

if [[ "$FOUND" -eq 1 ]]; then
  jq -n --arg result "$REDACTED" \
    '{"modifiedResult":{"textResultForLlm":$result,"resultType":"success"},"additionalContext":"⚠️ Secrets were detected and redacted from tool output. Never include credentials in code or commit messages."}'
fi
