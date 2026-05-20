#!/usr/bin/env bash
set -uo pipefail

INPUT="$(cat)"
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null) || TOOL_NAME=""
TOOL_INPUT=$(printf '%s' "$INPUT" | jq -c '.tool_input // {}' 2>/dev/null) || TOOL_INPUT="{}"

[[ "$TOOL_NAME" == "run_shell_command" ]] || exit 0

COMMAND=$(printf '%s' "$TOOL_INPUT" | jq -r '.command // ""' 2>/dev/null) || COMMAND=""
[[ -n "$COMMAND" ]] || exit 0

deny() {
  local reason="$1"
  jq -cn --arg reason "$reason" '{"decision":"deny","reason":$reason}'
  exit 0
}

# Block ansible-playbook without --check on non-localhost
if echo "$COMMAND" | grep -qE '(^|[;&|]\s*)ansible-playbook\b'; then
  if ! echo "$COMMAND" | grep -q '\-\-check' && ! echo "$COMMAND" | grep -q '\-\-connection[= ]local' && ! echo "$COMMAND" | grep -q '\-c local'; then
    deny "ansible-playbook must use --check (dry-run) first on non-local connections. Run with --check to verify, then remove it for the real run."
  fi
fi

# Redirect direct ansible-lint to make lint
if echo "$COMMAND" | grep -qE '(^|[;&|]\s*)ansible-lint\b'; then
  NEW_CMD=$(echo "$COMMAND" | sed -E 's/(^|[;&|]\s*)ansible-lint\b/\1make lint/g')
  jq -n --arg cmd "$NEW_CMD" \
    '{"updatedInput":{"command":$cmd}}'
  exit 0
fi

# Redirect direct molecule test to make test
if echo "$COMMAND" | grep -qE '(^|[;&|]\s*)molecule\b'; then
  NEW_CMD=$(echo "$COMMAND" | sed -E 's/(^|[;&|]\s*)molecule\b/\1make test/g')
  jq -n --arg cmd "$NEW_CMD" \
    '{"updatedInput":{"command":$cmd}}'
  exit 0
fi

exit 0
