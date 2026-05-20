#!/usr/bin/env bash
set -uo pipefail

INPUT="$(cat)"
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // "."' 2>/dev/null) || CWD="."

_current_branch_for_path() {
  local dir="$1"
  local branch
  branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
  local rc=$?
  if [ $rc -ne 0 ] || [ "$branch" = "HEAD" ]; then
    git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || true
  else
    printf '%s' "$branch"
  fi
}

BRANCH=$(_current_branch_for_path "$CWD")
[ -z "$BRANCH" ] && exit 0

if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  MSG="⛔ BRANCH-FIRST GUARD: Current branch is \"$BRANCH\". Create a feature branch before editing files: git checkout -b <type>/<slug>"
  jq -cn --arg msg "$MSG" '{systemMessage: $msg}'
else
  MSG="ℹ️ Branch: $BRANCH — good to edit files."
  jq -cn --arg msg "$MSG" '{systemMessage: $msg}'
fi
