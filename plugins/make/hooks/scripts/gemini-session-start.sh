#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="${extensionPath:-$(cd "$(dirname "$0")/../.." && pwd)}"

CTX="## Makefile + Python Policy Active\n\n"
CTX+="All Makefiles MUST follow these rules:\n"
CTX+="- \`.SILENT:\` — suppress recipe echoing\n"
CTX+="- \`.ONESHELL:\` — single shell per recipe\n"
CTX+="- \`.DEFAULT_GOAL:=help\` — default target is help\n"
CTX+="- NO \`@\` prefix — redundant with \`.SILENT:\`\n"
CTX+="- \`qa:\` target — MANDATORY quality gate\n\n"
CTX+="Use make targets exclusively: \`make fmt / lint / typecheck / test / qa\`\n\n"
CTX+="Python toolchain rules:\n"
CTX+="- Never use \`python\`, \`pip\`, or \`virtualenv\` directly — use \`uv\`\n"
CTX+="- Never use \`mypy\` directly — use \`zmypy\` (zuban drop-in)"

jq -cn --arg ctx "$CTX" '{hookSpecificOutput: {additionalContext: $ctx}}'
