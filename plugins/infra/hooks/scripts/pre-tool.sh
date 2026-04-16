#!/usr/bin/env bash
set -uo pipefail

INPUT="$(cat)"
TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.toolName // empty')"

[[ "$TOOL_NAME" == "bash" ]] || exit 0

TOOL_ARGS="$(printf '%s' "$INPUT" | jq -r '.toolArgs // empty')"
COMMAND="$(echo "$TOOL_ARGS" | jq -r '.command // empty')"
[[ -n "$COMMAND" ]] || exit 0

# Block ansible-playbook without --check on non-localhost
if echo "$COMMAND" | grep -qE '(^|[;&|]\s*)ansible-playbook\b'; then
  if ! echo "$COMMAND" | grep -q '\-\-check' && ! echo "$COMMAND" | grep -q '\-\-connection[= ]local' && ! echo "$COMMAND" | grep -q '\-c local'; then
    jq -cn '{"permissionDecision":"deny","permissionDecisionReason":"ansible-playbook must use --check (dry-run) first on non-local connections. Run with --check to verify, then remove it for the real run."}'
    exit 0
  fi
fi

# Redirect direct ansible-lint to make lint
if echo "$COMMAND" | grep -qE '(^|[;&|]\s*)ansible-lint\b'; then
  jq -n --arg cmd "make lint" \
    '{"modifiedArgs":{"command":$cmd},"additionalContext":"Redirected ansible-lint → make lint. Use make targets for all quality checks."}'
  exit 0
fi

# Redirect direct molecule test to make test
if echo "$COMMAND" | grep -qE '(^|[;&|]\s*)molecule\b'; then
  jq -n --arg cmd "make test" \
    '{"modifiedArgs":{"command":$cmd},"additionalContext":"Redirected molecule → make test. Use make targets for all testing."}'
  exit 0
fi

exit 0
