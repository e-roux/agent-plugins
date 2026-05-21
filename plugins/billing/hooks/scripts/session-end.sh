#!/usr/bin/env bash
# Persist a session's token usage to the billing plugin data directory.
# Receives the sessionEnd hook JSON payload on stdin.
set -euo pipefail

INPUT=$(cat)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.sessionId // .session_id // empty' 2>/dev/null)
[ -z "$SESSION_ID" ] && exit 0

# Discover COPILOT_HOME: env var > ~/.copilot > XDG
if [ -n "${COPILOT_HOME:-}" ] && [ -d "$COPILOT_HOME/session-state" ]; then
  :
elif [ -d "$HOME/.copilot/session-state" ]; then
  COPILOT_HOME="$HOME/.copilot"
elif [ -d "${XDG_CONFIG_HOME:-$HOME/.config}/copilot/session-state" ]; then
  COPILOT_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/copilot"
else
  exit 0
fi

SESSION_FILE="$COPILOT_HOME/session-state/$SESSION_ID/events.jsonl"
[ -f "$SESSION_FILE" ] || exit 0

SHUTDOWN=$(grep '"type":"session.shutdown"' "$SESSION_FILE" 2>/dev/null | tail -1)
[ -z "$SHUTDOWN" ] && exit 0

DATA_DIR="$COPILOT_HOME/plugin-data/e-roux-plugins/billing"
mkdir -p "$DATA_DIR"

printf '%s\n' "$SHUTDOWN" \
  | jq -c --arg sid "$SESSION_ID" '. + {session_id: $sid}' \
  >> "$DATA_DIR/usage.jsonl"
