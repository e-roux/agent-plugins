#!/usr/bin/env bash
# Hook: userPromptSubmitted
# Logs the prompt text to verify this hook fires on every user prompt.
INPUT=$(cat)
LOG_DIR="$(dirname "$0")/../logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/hook-trace.log"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
PROMPT=$(echo "$INPUT" | grep -o '"prompt":"[^"]*"' | cut -d'"' -f4 || echo "unparsed")
echo "[$TS] HOOK userPromptSubmitted FIRED — prompt: $PROMPT" >> "$LOG"
echo "  input: $INPUT" >> "$LOG"
