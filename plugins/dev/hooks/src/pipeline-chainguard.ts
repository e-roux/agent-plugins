import { readFileSync, existsSync } from "node:fs";
import { execSync } from "node:child_process";
import { currentBranch } from "./core.ts";
import type { PostToolInput, PostToolOutput } from "./core.ts";

function hasCommand(cmd: string): boolean {
  try {
    execSync(`command -v ${cmd}`, { stdio: ["ignore", "ignore", "ignore"] });
    return true;
  } catch {
    return false;
  }
}

function getCiContext(remote: string, branch: string): string {
  let ctx = `⚡ Pipeline Chainguard: code was pushed to ${remote}/${branch}`;

  if (hasCommand("gh")) {
    ctx += `.

**Action required — check CI pipeline status before continuing.**

Wait ~15 seconds for the pipeline to register, then run:
\`\`\`bash
sleep 15 && gh run list --branch "${branch}" --limit 3 --json status,conclusion,name,headBranch,event,createdAt
\`\`\`

If the run is \`in_progress\`, wait and re-check:
\`\`\`bash
gh run watch --exit-status
\`\`\`

If the run **failed**, diagnose with:
\`\`\`bash
gh run view <run-id> --log-failed
\`\`\`
Then fix the failure and push again. Do NOT proceed with new work while CI is broken.`;
  } else if (hasCommand("glab")) {
    ctx += `.

**Action required — check CI pipeline status before continuing.**

Wait ~15 seconds for the pipeline to register, then run:
\`\`\`bash
sleep 15 && glab ci status
\`\`\`

If the pipeline **failed**, diagnose with:
\`\`\`bash
glab ci view --log
\`\`\`
Then fix the failure and push again. Do NOT proceed with new work while CI is broken.`;
  } else {
    ctx += `.

**Action required — check CI pipeline status before continuing.**

Neither \`gh\` nor \`glab\` CLI was found. Check CI status manually in the repository's web UI. Do NOT proceed with new work until you confirm the pipeline passed.`;
  }

  return ctx;
}

export function runPipelineChainguard(input: PostToolInput): PostToolOutput {
  const toolName = input.toolName || "";
  const toolResult = input.toolResult || {};
  const toolInput = input.toolInput || input.toolArgs || {};
  const cwd = input.cwd || ".";

  const resultText = toolResult.textResultForLlm || JSON.stringify(toolResult);

  if (toolName === "mcp__git-ops__push") {
    if (/failed|error|denied|cannot/i.test(resultText)) {
      return {
        additionalContext: "⚠️ Pipeline Chainguard: git push FAILED. Fix the push error before checking CI.",
      };
    }

    const branch = toolInput.branch || currentBranch(cwd) || "HEAD";
    const remote = toolInput.remote || "origin";

    return {
      additionalContext: getCiContext(remote, branch),
    };
  }

  if (toolName !== "bash") {
    return {};
  }

  const cmd = toolInput.command || "";
  if (!cmd || !/git\s+push/.test(cmd)) {
    return {};
  }

  if (/rejected|failed|error|fatal|denied|non-fast-forward/i.test(resultText)) {
    return {
      additionalContext: "⚠️ Pipeline Chainguard: git push FAILED. Fix the push error before checking CI.",
    };
  }

  // Parse remote and branch
  // e.g. git push origin feat/x
  let remote = "origin";
  let branch = currentBranch(cwd) || "HEAD";

  const pushMatch = cmd.match(/git\s+push\s+(\S+)(?:\s+(\S+))?/);
  if (pushMatch) {
    if (pushMatch[1] && !pushMatch[1].startsWith("-")) {
      remote = pushMatch[1];
    }
    if (pushMatch[2] && !pushMatch[2].startsWith("-")) {
      branch = pushMatch[2];
    }
  }

  return {
    additionalContext: getCiContext(remote, branch),
  };
}

// CLI Execution entry point if run directly
if (import.meta.main) {
  try {
    const inputStr = readFileSync(0, "utf-8");
    const input: PostToolInput = JSON.parse(inputStr);
    const result = runPipelineChainguard(input);
    if (Object.keys(result).length > 0) {
      console.log(JSON.stringify(result));
    }
  } catch (err: any) {
    console.error("Error executing pipeline-chainguard guard:", err);
    process.exit(1);
  }
}
