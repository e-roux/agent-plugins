#!/usr/bin/env bash
set -uo pipefail

INPUT="$(cat)"
CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // "."')"

HAS_MEMORY=0
HAS_REQUIREMENTS=0

[[ -d "$CWD/.agents/memory" ]] && HAS_MEMORY=1
[[ -d "$CWD/doc/requirements" ]] && HAS_REQUIREMENTS=1

if [[ $HAS_MEMORY -eq 0 ]] && [[ $HAS_REQUIREMENTS -eq 0 ]]; then
  CTX="## Project Memory — Not Yet Configured\n\n"
  CTX+="This project does not have persistent agent memory.\n"
  CTX+="If the user asks to add **requirements**, **specifications**, **pitfalls**, or **lessons learned**, "
  CTX+="invoke the \`project-memory\` skill FIRST, then create the directory structure it describes:\n\n"
  CTX+="- Requirements → \`doc/requirements/features/<name>.md\`\n"
  CTX+="- Pitfalls → \`.agents/memory/known-pitfalls.md\`\n"
  CTX+="- Lessons → \`.agents/memory/lessons/<slug>.md\`\n\n"
  CTX+="**NEVER store requirements or specs in session state files.** They must be version-controlled in the project.\n"
  jq -cn --arg ctx "$CTX" '{"additionalContext":$ctx}'
  exit 0
fi

CTX="## Project Memory — Active\n\n"

if [[ $HAS_MEMORY -eq 1 ]]; then
  CTX+="### Pitfalls & Lessons\n\n"
  if [[ -f "$CWD/.agents/memory/known-pitfalls.md" ]]; then
    PITFALLS=$(cat "$CWD/.agents/memory/known-pitfalls.md")
    CTX+="${PITFALLS}\n\n"
  fi
  LESSONS=$(find "$CWD/.agents/memory/lessons" -name '*.md' -type f 2>/dev/null || true)
  if [[ -n "$LESSONS" ]]; then
    CTX+="**Lessons directory** contains:\n"
    echo "$LESSONS" | while IFS= read -r f; do
      [[ -f "$f" ]] && CTX+="  - $(basename "$f" .md)\n"
    done
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

jq -cn --arg ctx "$CTX" '{"additionalContext":$ctx}'
