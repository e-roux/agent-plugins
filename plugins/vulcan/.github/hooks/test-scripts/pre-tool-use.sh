#!/usr/bin/env bash
# Hook: preToolUse
# Logs tool name + args, then allows all tools (no deny output).
INPUT=$(cat)
LOG_DIR="$(dirname "$0")/../logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/hook-trace.log"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TOOL=$(echo "$INPUT" | grep -o '"toolName":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
echo "[$TS] HOOK preToolUse FIRED — tool: $TOOL" >> "$LOG"
echo "  input: $INPUT" >> "$LOG"
# Allow all tools — output permissionDecision:allow
echo '{"permissionDecision":"allow"}'
