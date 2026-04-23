#!/usr/bin/env bash
# Hook: errorOccurred
# Logs error name and message if this hook ever fires.
INPUT=$(cat)
LOG_DIR="$(dirname "$0")/../logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/hook-trace.log"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
ERR=$(echo "$INPUT" | grep -o '"message":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
echo "[$TS] HOOK errorOccurred FIRED — error: $ERR" >> "$LOG"
echo "  input: $INPUT" >> "$LOG"
