#!/usr/bin/env bash
# session-start.sh — Inject minimal cost-aware policy into session context.
# AOP pattern: one-time context injection replaces per-turn instructions.
set -euo pipefail

cat > /dev/null

CTX="## Cost-Aware Mode\n"
CTX+="Prefer cheapest capable model. Use premium models only for hard reasoning. "
CTX+="Delegate isolated high-context subtasks; keep simple work in-session."

jq -cn --arg ctx "$CTX" '{"additionalContext":$ctx}'
exit 0
