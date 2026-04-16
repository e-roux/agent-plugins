import { approveAll } from "@github/copilot-sdk";
import { joinSession } from "@github/copilot-sdk/extension";
import { execFile } from "node:child_process";

const CI_POLL_DELAY_MS = 18_000;
const CI_POLL_INTERVAL_MS = 15_000;
const CI_MAX_POLLS = 20;

let pendingPush = null;

function runCommand(cmd, args, cwd) {
  return new Promise((resolve) => {
    execFile(cmd, args, { timeout: 30_000, cwd }, (err, stdout, stderr) => {
      if (err) {
        resolve({ success: false, output: stderr || err.message });
      } else {
        resolve({ success: true, output: stdout.trim() });
      }
    });
  });
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function detectCIProvider(cwd) {
  const gh = await runCommand("gh", ["auth", "status"], cwd);
  if (gh.success) return "github";
  const glab = await runCommand("glab", ["auth", "status"], cwd);
  if (glab.success) return "gitlab";
  return null;
}

async function checkGitHubCI(branch, cwd) {
  const result = await runCommand("gh", [
    "run", "list",
    "--branch", branch,
    "--limit", "3",
    "--json", "status,conclusion,name,headBranch,event,createdAt,databaseId,url",
  ], cwd);
  if (!result.success) return { status: "error", detail: result.output };
  try {
    const runs = JSON.parse(result.output);
    if (runs.length === 0) return { status: "no_runs", detail: "No CI runs found for this branch." };
    const latest = runs[0];
    return {
      status: latest.status === "completed" ? latest.conclusion : latest.status,
      runId: latest.databaseId,
      name: latest.name,
      url: latest.url,
      detail: JSON.stringify(runs.slice(0, 3), null, 2),
    };
  } catch {
    return { status: "parse_error", detail: result.output };
  }
}

async function getGitHubFailureLogs(runId, cwd) {
  const result = await runCommand("gh", [
    "run", "view", String(runId), "--log-failed",
  ], cwd);
  return result.output.slice(-3000);
}

async function checkGitLabCI(branch, cwd) {
  const result = await runCommand("glab", ["ci", "status", "--branch", branch], cwd);
  if (!result.success) return { status: "error", detail: result.output };
  const output = result.output;
  if (/passed|success/i.test(output)) return { status: "success", detail: output };
  if (/failed/i.test(output)) return { status: "failure", detail: output };
  if (/running|pending/i.test(output)) return { status: "in_progress", detail: output };
  return { status: "raw", detail: output };
}

async function getCurrentBranch(cwd) {
  const result = await runCommand("git", ["rev-parse", "--abbrev-ref", "HEAD"], cwd);
  return result.success ? result.output : "HEAD";
}

const session = await joinSession({
  onPermissionRequest: approveAll,

  hooks: {
    onSessionStart: async () => ({
      additionalContext:
        "⚡ Pipeline Chainguard extension active. " +
        "CI pipeline status will be automatically checked after every git push. " +
        "You also have access to the `check_ci_pipeline` tool for manual checks.",
    }),

    onPostToolUse: async (input) => {
      if (input.toolName !== "bash") return;
      const command = String(input.toolArgs?.command || "");
      if (!/git\s+push/.test(command)) return;

      const resultText = String(
        input.toolResult?.textResultForLlm || input.toolResult || ""
      );
      if (/rejected|failed|error|fatal|denied|non-fast-forward/i.test(resultText)) {
        return {
          additionalContext:
            "⚠️ Pipeline Chainguard: git push failed. Fix the push error first.",
        };
      }

      const cwd = input.cwd || process.cwd();
      const branchMatch = command.match(/git\s+push\s+\S+\s+(\S+)/);
      const branch = branchMatch?.[1] || (await getCurrentBranch(cwd));
      const provider = await detectCIProvider(cwd);

      pendingPush = { branch, cwd, provider, timestamp: Date.now() };

      return {
        additionalContext:
          `⚡ Pipeline Chainguard: push to ${branch} detected. ` +
          `CI provider: ${provider || "unknown"}. ` +
          "The extension will automatically check pipeline status when you pause. " +
          "Or call `check_ci_pipeline` manually.",
      };
    },
  },

  tools: [
    {
      name: "check_ci_pipeline",
      description:
        "Check CI/CD pipeline status for the current branch. " +
        "Returns the latest run status from GitHub Actions or GitLab CI. " +
        "Use after git push to verify the pipeline passed.",
      skipPermission: true,
      parameters: {
        type: "object",
        properties: {
          branch: {
            type: "string",
            description:
              "Git branch to check. Defaults to current branch if omitted.",
          },
          wait: {
            type: "boolean",
            description:
              "If true, poll until the pipeline completes (up to 5 minutes). Default: false.",
          },
        },
      },
      handler: async (args) => {
        const cwd = process.cwd();
        const branch = args.branch || (await getCurrentBranch(cwd));
        const provider = await detectCIProvider(cwd);

        if (!provider) {
          return "No CI provider detected. Neither `gh` nor `glab` CLI is authenticated.";
        }

        if (provider === "github") {
          if (args.wait) {
            await sleep(CI_POLL_DELAY_MS);
            for (let i = 0; i < CI_MAX_POLLS; i++) {
              const ci = await checkGitHubCI(branch, cwd);
              if (ci.status === "success") {
                return `✅ Pipeline PASSED (${ci.name})\n${ci.url}`;
              }
              if (ci.status === "failure") {
                const logs = await getGitHubFailureLogs(ci.runId, cwd);
                return (
                  `❌ Pipeline FAILED (${ci.name})\n${ci.url}\n\n` +
                  `--- Failure logs (last 3000 chars) ---\n${logs}`
                );
              }
              if (ci.status === "no_runs") {
                if (i < 3) {
                  await sleep(CI_POLL_INTERVAL_MS);
                  continue;
                }
                return "No CI runs found after waiting. The repository may not have GitHub Actions configured.";
              }
              if (
                ci.status === "in_progress" ||
                ci.status === "queued" ||
                ci.status === "waiting" ||
                ci.status === "pending"
              ) {
                await sleep(CI_POLL_INTERVAL_MS);
                continue;
              }
              return `Pipeline status: ${ci.status}\n${ci.detail}`;
            }
            return "Pipeline still running after max polling time. Check manually.";
          }

          const ci = await checkGitHubCI(branch, cwd);
          if (ci.status === "success") return `✅ Pipeline PASSED (${ci.name})\n${ci.url}`;
          if (ci.status === "failure") {
            const logs = await getGitHubFailureLogs(ci.runId, cwd);
            return (
              `❌ Pipeline FAILED (${ci.name})\n${ci.url}\n\n` +
              `--- Failure logs (last 3000 chars) ---\n${logs}`
            );
          }
          return `Pipeline status: ${ci.status}\n${ci.detail}`;
        }

        if (provider === "gitlab") {
          const ci = await checkGitLabCI(branch, cwd);
          if (ci.status === "success") return `✅ GitLab pipeline PASSED\n${ci.detail}`;
          if (ci.status === "failure") {
            const logs = await runCommand("glab", ["ci", "view", "--branch", branch, "--log"], cwd);
            return `❌ GitLab pipeline FAILED\n${ci.detail}\n\n--- Failure logs ---\n${(logs.output || "").slice(-3000)}`;
          }
          return `GitLab CI status:\n${ci.detail}`;
        }

        return "Unsupported CI provider.";
      },
    },
  ],
});

session.on("session.idle", async () => {
  if (!pendingPush) return;

  const { branch, cwd, provider, timestamp } = pendingPush;
  pendingPush = null;

  const elapsed = Date.now() - timestamp;
  if (elapsed < CI_POLL_DELAY_MS) {
    await sleep(CI_POLL_DELAY_MS - elapsed);
  }

  if (provider !== "github") {
    if (provider === "gitlab") {
      const ci = await checkGitLabCI(branch, cwd);
      if (ci.status === "success") {
        await session.log(`✅ GitLab pipeline passed for ${branch}`, { level: "info" });
        return;
      }
      if (ci.status === "failure") {
        const logs = await runCommand("glab", ["ci", "view", "--branch", branch, "--log"], cwd);
        await session.send({
          prompt:
            `⚠️ Pipeline Chainguard: GitLab CI FAILED for branch ${branch}.\n\n` +
            `--- Failure logs ---\n\`\`\`\n${(logs.output || "").slice(-3000)}\n\`\`\`\n\n` +
            "Diagnose the failure, fix the code, and push again. " +
            "Do NOT start new work until CI is green.",
        });
        return;
      }
    }
    await session.send({
      prompt:
        `Pipeline Chainguard: You pushed to ${branch} but CI provider is ${provider || "unknown"}. ` +
        "Please check CI status manually and fix any failures before continuing.",
    });
    return;
  }

  let ci = await checkGitHubCI(branch, cwd);

  let polls = 0;
  while (
    (ci.status === "in_progress" || ci.status === "queued" ||
      ci.status === "waiting" || ci.status === "pending" ||
      ci.status === "no_runs") &&
    polls < CI_MAX_POLLS
  ) {
    await sleep(CI_POLL_INTERVAL_MS);
    ci = await checkGitHubCI(branch, cwd);
    polls++;
  }

  if (ci.status === "success") {
    await session.log(`✅ Pipeline passed for ${branch} (${ci.name})`, { level: "info" });
    return;
  }

  if (ci.status === "failure") {
    const logs = await getGitHubFailureLogs(ci.runId, cwd);
    await session.send({
      prompt:
        `⚠️ Pipeline Chainguard: CI pipeline FAILED for branch ${branch}.\n\n` +
        `Workflow: ${ci.name}\n` +
        `URL: ${ci.url}\n\n` +
        `--- Failure logs ---\n\`\`\`\n${logs}\n\`\`\`\n\n` +
        "Diagnose the failure, fix the code, and push again. " +
        "Do NOT start new work until CI is green.",
    });
    return;
  }

  if (ci.status === "no_runs") {
    await session.log(
      `Pipeline Chainguard: no CI runs found for ${branch}. Repo may not have Actions configured.`,
      { level: "warning" }
    );
    return;
  }

  await session.send({
    prompt:
      `Pipeline Chainguard: CI status for ${branch} is "${ci.status}" after polling. ` +
      `Details:\n\`\`\`\n${ci.detail}\n\`\`\`\n` +
      "Please investigate and ensure CI passes before continuing.",
  });
});

session.on("session.shutdown", () => {
  pendingPush = null;
});
