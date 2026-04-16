#!/usr/bin/env bash
set -uo pipefail

INPUT="$(cat)"
TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.toolName // empty')"

[[ "$TOOL_NAME" == "bash" ]] || exit 0

COMMAND="$(printf '%s' "$INPUT" | jq -r '.toolArgs.command // empty')"
[[ -n "$COMMAND" ]] || exit 0

if ! printf '%s' "$COMMAND" | grep -qE 'git\s+push'; then
  exit 0
fi

RESULT_TEXT="$(printf '%s' "$INPUT" | jq -r '.toolResult.textResultForLlm // .toolResult // empty')"
if printf '%s' "$RESULT_TEXT" | grep -qiE '(rejected|failed|error|fatal|denied|non-fast-forward)'; then
  jq -cn '{
    "additionalContext": "⚠️ Pipeline Chainguard: git push FAILED. Fix the push error before checking CI."
  }'
  exit 0
fi

REMOTE="$(printf '%s' "$COMMAND" | grep -oE 'git\s+push\s+\S+' | awk '{print $3}')"
REMOTE="${REMOTE:-origin}"
BRANCH="$(printf '%s' "$COMMAND" | grep -oE 'git\s+push\s+\S+\s+\S+' | awk '{print $4}')"
BRANCH="${BRANCH:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)}"

CONTEXT="⚡ Pipeline Chainguard: code was pushed to ${REMOTE}/${BRANCH}"

if command -v gh &>/dev/null 2>&1; then
  CONTEXT="${CONTEXT}.

**Action required — check CI pipeline status before continuing.**

Wait ~15 seconds for the pipeline to register, then run:
\`\`\`bash
sleep 15 && gh run list --branch \"${BRANCH}\" --limit 3 --json status,conclusion,name,headBranch,event,createdAt
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
  CONTEXT="${CONTEXT}.

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
  CONTEXT="${CONTEXT}.

**Action required — check CI pipeline status before continuing.**

Neither \`gh\` nor \`glab\` CLI was found. Check CI status manually in the repository's web UI. Do NOT proceed with new work until you confirm the pipeline passed."
fi

jq -cn --arg ctx "$CONTEXT" '{"additionalContext": $ctx}'
