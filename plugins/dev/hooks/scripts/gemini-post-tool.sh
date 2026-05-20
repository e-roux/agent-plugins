#!/usr/bin/env bash
set -uo pipefail

INPUT="$(cat)"
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null) || TOOL_NAME=""

# ── Redaction Logic ──
LLM_CONTENT=$(printf '%s' "$INPUT" | jq -r '.tool_response.llmContent // ""' 2>/dev/null) || LLM_CONTENT=""
[ -z "$LLM_CONTENT" ] && exit 0

REDACTED="$LLM_CONTENT"
FOUND=0

# Redaction patterns
REDACTED=$(echo "$REDACTED" | sed -E 's/gh[ps]_[a-zA-Z0-9]{36}/[REDACTED_GITHUB_TOKEN]/g')
[[ "$REDACTED" != "$LLM_CONTENT" ]] && FOUND=1

TEMP="$REDACTED"
REDACTED=$(echo "$REDACTED" | sed -E 's/gho_[a-zA-Z0-9]{36}/[REDACTED_GITHUB_OAUTH]/g')
[[ "$REDACTED" != "$TEMP" ]] && FOUND=1

TEMP="$REDACTED"
REDACTED=$(echo "$REDACTED" | sed -E 's/AKIA[A-Z0-9]{16}/[REDACTED_AWS_KEY]/g')
[[ "$REDACTED" != "$TEMP" ]] && FOUND=1

TEMP="$REDACTED"
REDACTED=$(echo "$REDACTED" | sed -E 's/sk-[a-zA-Z0-9]{32,}/[REDACTED_API_KEY]/g')
[[ "$REDACTED" != "$TEMP" ]] && FOUND=1

if echo "$REDACTED" | grep -q 'BEGIN.*PRIVATE KEY'; then
  REDACTED=$(echo "$REDACTED" | sed '/BEGIN.*PRIVATE KEY/,/END.*PRIVATE KEY/c\[REDACTED_PRIVATE_KEY]')
  FOUND=1
fi

if [ "$FOUND" -eq 1 ]; then
  MSG="⚠️ Secrets were detected and redacted from tool output. Never include credentials in code or commit messages."
  jq -n --arg reason "$REDACTED" --arg msg "$MSG" \
    '{"decision":"deny", "reason":$reason, "systemMessage":$msg}'
  exit 0
fi

# ── Release Reminder Logic ──
if [[ "$TOOL_NAME" == "run_shell_command" ]]; then
  CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null) || CMD=""
  if printf '%s' "$CMD" | grep -qE 'git[[:space:]]+tag\b.*v[0-9]'; then
    ERROR=$(printf '%s' "$INPUT" | jq -r '.tool_response.error // ""' 2>/dev/null) || ERROR=""
    if [ -z "$ERROR" ]; then
      TAG_VER=$(printf '%s' "$CMD" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+([-.][a-zA-Z0-9]+)?' | head -1)
      TAG_REF="${TAG_VER:-<tag>}"
      CTX="Tag ${TAG_REF} created locally. Next steps:
1. Push the tag: git push origin ${TAG_REF}
2. Build artifacts if applicable: make release
3. Create platform release: use mcp__git-ops__create_release (preferred) or gh/glab release create"
      jq -n --arg ctx "$CTX" '{hookSpecificOutput: {additionalContext: $ctx}}'
      exit 0
    fi
  fi
fi

exit 0
