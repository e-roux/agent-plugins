#!/usr/bin/env bash
# Hook: sessionStart
# Logs invocation with full input JSON to verify this hook fires.
INPUT=$(cat)
LOG_DIR="$(dirname "$0")/../logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/hook-trace.log"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "[$TS] HOOK sessionStart FIRED" >> "$LOG"
echo "  input: $INPUT" >> "$LOG"
