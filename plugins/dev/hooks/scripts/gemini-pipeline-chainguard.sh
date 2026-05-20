#!/usr/bin/env bash
set -uo pipefail

INPUT="$(cat)"
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null) || TOOL_NAME=""

_ci_context() {
  local remote="$1" branch="$2"
  local ctx="⚡ Pipeline Chainguard: code was pushed to ${remote}/${branch}"
  if command -v gh &>/dev/null 2>&1; then
    ctx="${ctx}.

**Action required — check CI pipeline status before continuing.**

Wait ~15 seconds for the pipeline to register, then run:
\`\`\`bash
sleep 15 && gh run list --branch \"${branch}\" --limit 3 --json status,conclusion,name,headBranch,event,createdAt
\`\`\`

If the run is \`in_progress\`, wait and re-check:
\`\`\`bash
gh run watch --exit-status
\`\`\`

If the run **failed**, diagnose with:
\`\`\`bash
gh run view <run-id> --log-failed
\`\`\`
Then fix the failure and push again. Do NOT proceed with new work while CI is broken."
  elif command -v glab &>/dev/null 2>&1; then
    ctx="${ctx}.

**Action required — check CI pipeline status before continuing.**

Wait ~15 seconds for the pipeline to register, then run:
\`\`\`bash
sleep 15 && glab ci status
\`\`\`

If the pipeline **failed**, diagnose with:
\`\`\`bash
glab ci view --log
\`\`\`
Then fix the failure and push again. Do NOT proceed with new work while CI is broken."
  else
    ctx="${ctx}.

**Action required — check CI pipeline status before continuing.**

Neither \`gh\` nor \`glab\` CLI was found. Check CI status manually in the repository's web UI. Do NOT proceed with new work until you confirm the pipeline passed."
  fi
  printf '%s' "$ctx"
}

[[ "$TOOL_NAME" == "run_shell_command" ]] || exit 0

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null) || CMD=""
[[ -n "$CMD" ]] || exit 0

if ! printf '%s' "$CMD" | grep -qE 'git\s+push'; then
  exit 0
fi

ERROR=$(printf '%s' "$INPUT" | jq -r '.tool_response.error // ""' 2>/dev/null) || ERROR=""
if [[ -n "$ERROR" ]] || printf '%s' "$(printf '%s' "$INPUT" | jq -r '.tool_response.llmContent // ""' 2>/dev/null)" | grep -qiE '(rejected|failed|error|fatal|denied|non-fast-forward)'; then
  jq -cn '{hookSpecificOutput: {additionalContext: "⚠️ Pipeline Chainguard: git push FAILED. Fix the push error before checking CI."}}'
  exit 0
fi

REMOTE="$(printf '%s' "$CMD" | grep -oE 'git\s+push\s+\S+' | awk '{print $3}')"
REMOTE="${REMOTE:-origin}"
BRANCH="$(printf '%s' "$CMD" | grep -oE 'git\s+push\s+\S+\s+\S+' | awk '{print $4}')"
BRANCH="${BRANCH:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)}"

jq -cn --arg ctx "$(_ci_context "$REMOTE" "$BRANCH")" '{hookSpecificOutput: {additionalContext: $ctx}}'
