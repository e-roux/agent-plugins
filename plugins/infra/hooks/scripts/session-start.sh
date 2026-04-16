#!/usr/bin/env bash
set -euo pipefail

jq -cn '{additionalContext: "## Ansible/Molecule Policy Active\n\nRules enforced by preToolUse hook:\n- `ansible-playbook` requires `--check` (dry-run) before real runs on non-local connections\n- `ansible-galaxy` collection installs must include `--force` to avoid stale cache\n- Always use `make` targets when available: `make test` (molecule), `make lint` (ansible-lint)\n- Molecule tests use Podman driver by default — do not switch to Docker without discussion"}'
