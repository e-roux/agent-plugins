#!/usr/bin/env bash
set -uo pipefail

INPUT="$(cat)"
CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // ""')"
[ -z "$CWD" ] && exit 0

BRANCH=$(git -C "$CWD" rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0
[ -z "$BRANCH" ] && exit 0
[ "$BRANCH" = "HEAD" ] && exit 0

if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  printf '⛔ BRANCH-FIRST GUARD: Current branch is "%s" in %s.\n' "$BRANCH" "$CWD"
  printf 'You MUST create a feature branch before editing any files:\n'
  printf '  git checkout -b <type>/<descriptive-slug>\n'
  printf 'Types: feat/ fix/ chore/ docs/ refactor/ test/\n'
  printf 'The preToolUse hook will block edit/create/bash-write attempts on this branch.\n'
else
  printf 'ℹ️ Branch: %s — good to edit files.\n' "$BRANCH"
fi
