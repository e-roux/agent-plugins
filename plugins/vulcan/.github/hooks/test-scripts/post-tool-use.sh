#!/usr/bin/env bash
# Hook: postToolUse
# Logs tool name and result type after each tool execution.
INPUT=$(cat)
LOG_DIR="$(dirname "$0")/../logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/hook-trace.log"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TOOL=$(echo "$INPUT" | grep -o '"toolName":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
RESULT=$(echo "$INPUT" | grep -o '"resultType":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
echo "[$TS] HOOK postToolUse FIRED — tool: $TOOL, result: $RESULT" >> "$LOG"
echo "  input: $INPUT" >> "$LOG"
