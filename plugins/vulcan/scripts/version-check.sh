#!/usr/bin/env bash
set -euo pipefail

PLUGIN_JSON="plugin.json"

PLUGIN_DIR="${COPILOT_PLUGIN_ROOT:-${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}}"
if [[ -n "$PLUGIN_DIR" && -f "${PLUGIN_DIR}/${PLUGIN_JSON}" ]]; then
  cd "$PLUGIN_DIR"
elif [[ -n "${CLAUDE_PROJECT_DIR:-}" && -f "${CLAUDE_PROJECT_DIR}/${PLUGIN_JSON}" ]]; then
  cd "$CLAUDE_PROJECT_DIR"
fi

if [[ ! -f "$PLUGIN_JSON" ]]; then
  exit 0
fi

CURRENT_VERSION=$(grep -o '"version": *"[^"]*"' "$PLUGIN_JSON" | head -1 | grep -o '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*')

# Last commit that touched plugin.json — treat as the version baseline
LAST_BUMP=$(git log --format="%H" -1 -- plugin.json 2>/dev/null)
if [[ -z "$LAST_BUMP" ]]; then
  exit 0
fi

# Committed changes to version-sensitive dirs since the last version bump
COMMITTED_SKILLS=$(git diff --name-only "$LAST_BUMP" HEAD -- skills/ 2>/dev/null | wc -l | tr -d ' ')
COMMITTED_AGENTS=$(git diff --name-only "$LAST_BUMP" HEAD -- agents/ 2>/dev/null | wc -l | tr -d ' ')
COMMITTED_RESOURCES=$(git diff --name-only "$LAST_BUMP" HEAD -- resources/ 2>/dev/null | wc -l | tr -d ' ')

# Uncommitted changes (modified tracked + untracked)
UNCOMMITTED_SKILLS=$(git diff --name-only HEAD -- skills/ 2>/dev/null | wc -l | tr -d ' ')
UNCOMMITTED_AGENTS=$(git diff --name-only HEAD -- agents/ 2>/dev/null | wc -l | tr -d ' ')
UNCOMMITTED_RESOURCES=$(git diff --name-only HEAD -- resources/ 2>/dev/null | wc -l | tr -d ' ')
UNTRACKED_SKILLS=$(git ls-files --others --exclude-standard 2>/dev/null | grep -c '^skills/' || true)
UNTRACKED_AGENTS=$(git ls-files --others --exclude-standard 2>/dev/null | grep -c '^agents/' || true)
UNTRACKED_RESOURCES=$(git ls-files --others --exclude-standard 2>/dev/null | grep -c '^resources/' || true)

COMMITTED_TOTAL=$((COMMITTED_SKILLS + COMMITTED_AGENTS + COMMITTED_RESOURCES))
UNCOMMITTED_TOTAL=$((UNCOMMITTED_SKILLS + UNCOMMITTED_AGENTS + UNCOMMITTED_RESOURCES + UNTRACKED_SKILLS + UNTRACKED_AGENTS + UNTRACKED_RESOURCES))
TOTAL_CHANGES=$((COMMITTED_TOTAL + UNCOMMITTED_TOTAL))

if [[ "$TOTAL_CHANGES" -gt 0 ]]; then
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║  VERSION CHECK: plugin.json is currently at v${CURRENT_VERSION}"
  echo "║"
  if [[ "$COMMITTED_TOTAL" -gt 0 ]]; then
    echo "║  Committed since last plugin.json change (needs bump):"
    [[ "$COMMITTED_SKILLS" -gt 0 ]]    && echo "║    skills/     ${COMMITTED_SKILLS} file(s)"
    [[ "$COMMITTED_AGENTS" -gt 0 ]]    && echo "║    agents/     ${COMMITTED_AGENTS} file(s)"
    [[ "$COMMITTED_RESOURCES" -gt 0 ]] && echo "║    resources/  ${COMMITTED_RESOURCES} file(s)"
  fi
  if [[ "$UNCOMMITTED_TOTAL" -gt 0 ]]; then
    echo "║  Uncommitted:"
    [[ "$((UNCOMMITTED_SKILLS + UNTRACKED_SKILLS))" -gt 0 ]]     && echo "║    skills/     ${UNCOMMITTED_SKILLS} modified, ${UNTRACKED_SKILLS} new"
    [[ "$((UNCOMMITTED_AGENTS + UNTRACKED_AGENTS))" -gt 0 ]]     && echo "║    agents/     ${UNCOMMITTED_AGENTS} modified, ${UNTRACKED_AGENTS} new"
    [[ "$((UNCOMMITTED_RESOURCES + UNTRACKED_RESOURCES))" -gt 0 ]] && echo "║    resources/  ${UNCOMMITTED_RESOURCES} modified, ${UNTRACKED_RESOURCES} new"
  fi
  echo "║"
  echo "║  Consider bumping the version in plugin.json:"
  echo "║    patch — bug fixes, typo corrections"
  echo "║    minor — new skill/resource, meaningful content additions"
  echo "║    major — breaking changes, removed/renamed skills"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""
fi
