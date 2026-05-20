#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="${extensionPath:-$(cd "$(dirname "$0")/../.." && pwd)}"
CWD=$(pwd)

CTX="## Dev Guards Active\n\n"
CTX+="Rules enforced:\n"
CTX+="- **Secrets Guard**: Blocks hardcoded credentials\n"
CTX+="- **Branch Guard**: Blocks direct push/merge to main\n"
CTX+="- **Branch-First Guard**: Blocks file edits while on main/master\n"
CTX+="- **Migration Guard**: Blocks destructive SQL in migrations\n"
CTX+="- **No-Comments Guard**: Code must be self-documenting (no comments in source)\n"
CTX+="- **QA Gate**: git commit blocked if \`make qa\` fails\n"
CTX+="- **Pipeline Chainguard**: Monitors CI status after push"

jq -cn --arg ctx "$CTX" '{hookSpecificOutput: {additionalContext: $ctx}}'
