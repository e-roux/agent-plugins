#!/usr/bin/env bash
# Hook: sessionEnd
# Logs the session end reason to verify this hook fires on exit.
INPUT=$(cat)
LOG_DIR="$(dirname "$0")/../logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/hook-trace.log"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
REASON=$(echo "$INPUT" | grep -o '"reason":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
echo "[$TS] HOOK sessionEnd FIRED — reason: $REASON" >> "$LOG"
echo "  input: $INPUT" >> "$LOG"
