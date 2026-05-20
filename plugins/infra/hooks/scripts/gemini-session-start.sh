#!/usr/bin/env bash
set -euo pipefail

CTX="## Ansible/Molecule Policy Active\n\n"
CTX+="Rules enforced by BeforeTool hook:\n"
CTX+="- \`ansible-playbook\` requires \`--check\` (dry-run) before real runs on non-local connections\n"
CTX+="- \`ansible-galaxy\` collection installs must include \`--force\` to avoid stale cache\n"
CTX+="- Always use \`make\` targets when available: \`make test\` (molecule), \`make lint\` (ansible-lint)\n"
CTX+="- Molecule tests use Podman driver by default — do not switch to Docker without discussion"

jq -cn --arg ctx "$CTX" '{hookSpecificOutput: {additionalContext: $ctx}}'
