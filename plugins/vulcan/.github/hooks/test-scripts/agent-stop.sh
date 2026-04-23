#!/usr/bin/env bash
# Hook: agentStop
# Fires when the main agent has finished responding to a prompt.
INPUT=$(cat)
LOG_DIR="$(dirname "$0")/../logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/hook-trace.log"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "[$TS] HOOK agentStop FIRED" >> "$LOG"
echo "  input: $INPUT" >> "$LOG"
