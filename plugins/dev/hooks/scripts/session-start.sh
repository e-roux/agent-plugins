#!/usr/bin/env bash
# session-start.sh — Inject dev guards policy + requirements injection.
set -euo pipefail

PLUGIN_ROOT="${COPILOT_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
LOG_DIR="$PLUGIN_ROOT/hooks/logs"

INPUT="$(cat)"
CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // "unknown"')"

CTX="## Dev Guards Active\n\n"
CTX+="General-purpose guards are enforced:\n"
CTX+="- **secrets-guard**: no hardcoded credentials — use env vars\n"
CTX+="- **no-comments-guard**: code must be self-documenting — no comment lines in source files\n"
CTX+="- **branch-guard**: never push/merge to \`main\` directly — use PRs\n"
CTX+="- **migration-guard**: no DROP/TRUNCATE/DELETE in SQL migrations\n"
CTX+="- **no-verify-guard**: \`--no-verify\` is forbidden on commits\n"
CTX+="- **pipeline-chainguard**: after every \`git push\`, check CI pipeline status before continuing\n\n"
CTX+="All guards apply to every project in this session.\n\n"

HAS_MEMORY=0
HAS_REQUIREMENTS=0

[[ -d "$CWD/.agents/memory" ]] && HAS_MEMORY=1
[[ -d "$CWD/doc/requirements" ]] && HAS_REQUIREMENTS=1

if [[ $HAS_MEMORY -eq 0 ]] && [[ $HAS_REQUIREMENTS -eq 0 ]]; then
  CTX+="## Project Memory — Not Yet Configured\n\n"
  CTX+="This project does not have persistent agent memory.\n"
  CTX+="If the user asks to add **requirements**, **specifications**, **pitfalls**, or **lessons learned**, "
  CTX+="create the directory structure:\n\n"
  CTX+="- Requirements → \`doc/requirements/features/<name>.md\`\n"
  CTX+="- Pitfalls → \`.agents/memory/known-pitfalls.md\`\n"
  CTX+="- Lessons → \`.agents/memory/lessons/<slug>.md\`\n\n"
  CTX+="**NEVER store requirements or specs in session state files.** They must be version-controlled in the project.\n"
else
  CTX+="## Project Memory — Active\n\n"

  if [[ $HAS_MEMORY -eq 1 ]]; then
    CTX+="### Pitfalls & Lessons\n\n"
    if [[ -f "$CWD/.agents/memory/known-pitfalls.md" ]]; then
      PITFALLS=$(cat "$CWD/.agents/memory/known-pitfalls.md")
      CTX+="${PITFALLS}\n\n"
    fi
    LESSONS=$(find "$CWD/.agents/memory/lessons" -name '*.md' -type f 2>/dev/null || true)
    if [[ -n "$LESSONS" ]]; then
      CTX+="**Lessons directory** contains:\n"
      while IFS= read -r f; do
        [[ -f "$f" ]] && CTX+="  - $(basename "$f" .md)\n"
      done <<< "$LESSONS"
    fi
  fi

  if [[ $HAS_REQUIREMENTS -eq 1 ]]; then
    CTX+="### Feature Requirements\n\n"
    CTX+="Existing requirement specs:\n"
    REQS=$(find "$CWD/doc/requirements" -name '*.md' -type f 2>/dev/null || true)
    if [[ -n "$REQS" ]]; then
      while IFS= read -r f; do
        [[ -f "$f" ]] || continue
        rel="${f#"$CWD"/}"
        CTX+="  - \`${rel}\`\n"
      done <<< "$REQS"
    else
      CTX+="  (none yet)\n"
    fi
    CTX+="\nWhen adding new requirements: \`doc/requirements/features/<name>.md\`\n"
  fi

  CTX+="\n**RULES:**\n"
  CTX+="- Requirements and specs → \`doc/requirements/features/<name>.md\` (NEVER session state)\n"
  CTX+="- Pitfalls → \`.agents/memory/known-pitfalls.md\`\n"
  CTX+="- Lessons → \`.agents/memory/lessons/<slug>.md\`\n"
  CTX+="- Read existing pitfalls BEFORE making changes\n"
  CTX+="- Read relevant requirement specs BEFORE implementing features\n"
fi

jq -cn --arg ctx "$CTX" '{"additionalContext":$ctx}'

mkdir -p "$LOG_DIR" && \
  echo "session-start fired at $(date -u +%Y-%m-%dT%H:%M:%SZ), cwd=${CWD}" >> "$LOG_DIR/session-start.log" \
  || true

exit 0
