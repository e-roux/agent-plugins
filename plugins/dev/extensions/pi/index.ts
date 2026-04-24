import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "typebox";
import { execFile } from "node:child_process";
import { readFileSync, existsSync, mkdirSync, appendFileSync } from "node:fs";
import { basename, dirname, resolve } from "node:path";

const SECRET_PATTERN =
  /(JWT_SECRET|API_KEY|CLIENT_SECRET|OIDC_CLIENT_SECRET|DB_PASS(?:WORD)?|MONGODB_URI|RABBITMQ_URL|PRIVATE_KEY|ACCESS_TOKEN_SECRET|SECRET_KEY|PASSWORD|PASSWD)\s*:?=\s*["'][^"']{8,}["']/;

const COMMENT_EXTENSIONS = new Set([
  ".go", ".ts", ".tsx", ".js", ".jsx", ".py", ".rs",
  ".java", ".c", ".cpp", ".h", ".cs", ".rb", ".swift", ".kt",
]);

const TEST_CONFIG_PATTERN =
  /(_test\.(go|ts|js|rs|py)|\.test\.(ts|js)|spec\.(ts|js)|\.example|\.md|\.template|testdata|\.bats|\/test\/)/;

const TOKEN_PATTERNS: Array<[RegExp, string]> = [
  [/gh[ps]_[a-zA-Z0-9]{36}/g, "[REDACTED_GITHUB_TOKEN]"],
  [/gho_[a-zA-Z0-9]{36}/g, "[REDACTED_GITHUB_OAUTH]"],
  [/AKIA[A-Z0-9]{16}/g, "[REDACTED_AWS_KEY]"],
  [/sk-[a-zA-Z0-9]{32,}/g, "[REDACTED_API_KEY]"],
  [/[0-9a-f]{64,}/g, "[REDACTED_TOKEN]"],
];

const MCP_CB_FILE = "/tmp/.mcp-git-ops-cb";
const MCP_CB_TTL = 300;

function isTestOrConfig(path: string): boolean {
  return TEST_CONFIG_PATTERN.test(path);
}

function currentBranch(cwd: string): string {
  try {
    const { execFileSync } = require("node:child_process");
    const branch = execFileSync("git", ["rev-parse", "--abbrev-ref", "HEAD"], {
      cwd,
      timeout: 5000,
      encoding: "utf-8",
    }).trim();
    if (branch === "HEAD") {
      return execFileSync("git", ["symbolic-ref", "--short", "HEAD"], {
        cwd,
        timeout: 5000,
        encoding: "utf-8",
      }).trim();
    }
    return branch;
  } catch {
    return "";
  }
}

function isProtectedBranch(branch: string): boolean {
  return branch === "main" || branch === "master";
}

function mpcGitOpsAvailable(): boolean {
  try {
    const { execFileSync } = require("node:child_process");
    execFileSync("which", ["mcp-git-ops"], { timeout: 3000 });
  } catch {
    return false;
  }
  if (existsSync(MCP_CB_FILE)) {
    try {
      const tripped = parseInt(readFileSync(MCP_CB_FILE, "utf-8").trim(), 10);
      const age = Math.floor(Date.now() / 1000) - tripped;
      if (age < MCP_CB_TTL) return false;
    } catch {}
  }
  return true;
}

function runCmd(cmd: string, args: string[], cwd: string): Promise<{ ok: boolean; out: string }> {
  return new Promise((res) => {
    execFile(cmd, args, { timeout: 30_000, cwd }, (err, stdout, stderr) => {
      res(err ? { ok: false, out: stderr || err.message } : { ok: true, out: stdout.trim() });
    });
  });
}

function redactSecrets(text: string): { redacted: string; found: boolean } {
  let result = text;
  let found = false;
  for (const [pattern, replacement] of TOKEN_PATTERNS) {
    if (pattern.test(result)) {
      result = result.replace(pattern, replacement);
      found = true;
    }
  }
  if (/BEGIN.*PRIVATE KEY/.test(result)) {
    result = result.replace(/-----BEGIN[^-]*PRIVATE KEY-----[\s\S]*?-----END[^-]*PRIVATE KEY-----/g, "[REDACTED_PRIVATE_KEY]");
    found = true;
  }
  return { redacted: result, found };
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    ctx.ui.notify("🛡️ Dev guards active (secrets, comments, branches, migrations, CI pipeline)", "info");
  });

  pi.on("tool_call", async (event, _ctx) => {
    const tool = event.toolName;
    const input = event.input || {};

    if (tool === "write" || tool === "edit") {
      const filePath: string = input.path || input.file_path || "";
      const content: string = input.content || input.new_str || input.file_text || "";

      if (filePath && !isTestOrConfig(filePath)) {
        if (SECRET_PATTERN.test(content)) {
          return {
            block: true,
            reason: `Secrets guard: potential hardcoded credential in ${basename(filePath)}. Use environment variables instead.`,
          };
        }

        const ext = filePath.match(/\.[^./]+$/)?.[0] || "";
        if (COMMENT_EXTENSIONS.has(ext)) {
          if (/^\s*(\/\/|\/\*|\*\/)/m.test(content)) {
            return {
              block: true,
              reason: "No-comments guard: code must be self-documenting. Express intent through clear naming, not comment lines.",
            };
          }
          const lines = content.split("\n");
          const hasHashComment = lines.some(
            (l) => /^\s*#/.test(l) && !/^\s*#!/.test(l),
          );
          if (hasHashComment) {
            return {
              block: true,
              reason: "No-comments guard: code must be self-documenting. Express intent through clear naming, not comment lines.",
            };
          }
        }
      }

      if (filePath) {
        const dir = dirname(filePath);
        const checkDir = existsSync(dir) ? dir : process.cwd();
        const branch = currentBranch(checkDir);
        if (isProtectedBranch(branch)) {
          return {
            block: true,
            reason: `Branch-first guard: you are on '${branch}'. Create a feature branch first: git checkout -b <type>/<descriptive-slug>`,
          };
        }
      }
    }

    if (tool === "bash") {
      const cmd: string = input.command || "";
      if (!cmd) return;

      if (/git\s+push\b/.test(cmd) && mpcGitOpsAvailable()) {
        return {
          block: true,
          reason: "Use the mcp__git-ops__push tool instead of bash git push.",
        };
      }
      if (/(gh\s+pr\s+create|glab\s+mr\s+create|az\s+repos\s+pr\s+create)\b/.test(cmd) && mpcGitOpsAvailable()) {
        return {
          block: true,
          reason: "Use the mcp__git-ops__create_pr tool instead.",
        };
      }
      if (/(gh\s+pr\s+merge|glab\s+mr\s+merge)\b/.test(cmd) && mpcGitOpsAvailable()) {
        return {
          block: true,
          reason: "Use the mcp__git-ops__merge_pr tool instead.",
        };
      }

      if (/(>[^/dev]|>>[^/dev]|\stee\s[^-]|sed\s+-[^ ]*i)/.test(cmd)) {
        const branch = currentBranch(process.cwd());
        if (isProtectedBranch(branch)) {
          return {
            block: true,
            reason: `Branch-first guard: you are on '${branch}'. Create a feature branch first: git checkout -b <type>/<descriptive-slug>`,
          };
        }
      }

      if (/migrations?\/|\.sql/i.test(cmd)) {
        if (/(DROP\s+(TABLE|COLUMN|SCHEMA)|TRUNCATE\s+TABLE|DELETE\s+FROM)/i.test(cmd)) {
          return {
            block: true,
            reason: "Migration guard: destructive SQL (DROP/TRUNCATE/DELETE) is forbidden. Use additive changes only.",
          };
        }
      }

      if (/git\s+(push|merge)\s[^&|;]*\bmain\b/.test(cmd)) {
        return {
          block: true,
          reason: "Branch guard: never push/merge to main directly. Use a PR.",
        };
      }

      if (/git\s+commit\s+.*--no-verify/.test(cmd)) {
        return {
          block: true,
          reason: "No-verify guard: --no-verify bypasses commit hooks. Remove the flag.",
        };
      }
    }
  });

  pi.on("tool_result", async (event, _ctx) => {
    if (event.toolName === "bash") {
      const output = String(event.result?.content?.[0]?.text || "");
      const { redacted, found } = redactSecrets(output);
      if (found) {
        return {
          modifiedResult: {
            content: [{ type: "text", text: redacted }],
            details: {},
          },
        };
      }
    }
  });

  const CI_POLL_DELAY = 18_000;
  const CI_POLL_INTERVAL = 15_000;
  const CI_MAX_POLLS = 20;

  let pendingPush: { branch: string; cwd: string; provider: string | null; timestamp: number } | null = null;

  pi.on("tool_result", async (event, ctx) => {
    if (event.toolName !== "bash") return;
    const cmd = String(event.input?.command || "");
    if (!/git\s+push/.test(cmd)) return;

    const output = String(event.result?.content?.[0]?.text || "");
    if (/rejected|failed|error|fatal|denied|non-fast-forward/i.test(output)) {
      ctx.ui.notify("⚠️ Pipeline Chainguard: git push failed. Fix the error first.", "warning");
      return;
    }

    const cwd = process.cwd();
    const branchMatch = cmd.match(/git\s+push\s+\S+\s+(\S+)/);
    const branch = branchMatch?.[1] || currentBranch(cwd);
    const gh = await runCmd("gh", ["auth", "status"], cwd);
    const provider = gh.ok ? "github" : null;

    pendingPush = { branch, cwd, provider, timestamp: Date.now() };
    ctx.ui.notify(`⚡ Pipeline Chainguard: push to ${branch} detected. Use check_ci_pipeline to monitor.`, "info");
  });

  pi.registerTool({
    name: "check_ci_pipeline",
    label: "Check CI Pipeline",
    description:
      "Check CI/CD pipeline status for a branch. Returns the latest run status from GitHub Actions or GitLab CI. Use after git push to verify the pipeline passed.",
    parameters: Type.Object({
      branch: Type.Optional(Type.String({ description: "Git branch to check. Defaults to current branch." })),
      wait: Type.Optional(Type.Boolean({ description: "If true, poll until pipeline completes (up to 5 min)." })),
    }),
    async execute(_toolCallId, params, signal, _onUpdate, _ctx) {
      const cwd = process.cwd();
      const branch = params.branch || currentBranch(cwd);
      const gh = await runCmd("gh", ["auth", "status"], cwd);

      if (!gh.ok) {
        return { content: [{ type: "text", text: "No CI provider detected. `gh` CLI is not authenticated." }], details: {} };
      }

      const checkGH = async () => {
        const r = await runCmd("gh", ["run", "list", "--branch", branch, "--limit", "3", "--json", "status,conclusion,name,url,databaseId"], cwd);
        if (!r.ok) return { status: "error", detail: r.out, url: "", runId: 0, name: "" };
        try {
          const runs = JSON.parse(r.out);
          if (!runs.length) return { status: "no_runs", detail: "No CI runs found.", url: "", runId: 0, name: "" };
          const latest = runs[0];
          return {
            status: latest.status === "completed" ? latest.conclusion : latest.status,
            runId: latest.databaseId,
            name: latest.name,
            url: latest.url,
            detail: JSON.stringify(runs.slice(0, 3), null, 2),
          };
        } catch {
          return { status: "parse_error", detail: r.out, url: "", runId: 0, name: "" };
        }
      };

      if (params.wait) {
        await new Promise((r) => setTimeout(r, CI_POLL_DELAY));
        for (let i = 0; i < CI_MAX_POLLS; i++) {
          if (signal?.aborted) break;
          const ci = await checkGH();
          if (ci.status === "success") {
            return { content: [{ type: "text", text: `✅ Pipeline PASSED (${ci.name})\n${ci.url}` }], details: {} };
          }
          if (ci.status === "failure") {
            const logs = await runCmd("gh", ["run", "view", String(ci.runId), "--log-failed"], cwd);
            return { content: [{ type: "text", text: `❌ Pipeline FAILED (${ci.name})\n${ci.url}\n\n${logs.out.slice(-3000)}` }], details: {} };
          }
          if (["in_progress", "queued", "waiting", "pending", "no_runs"].includes(ci.status)) {
            await new Promise((r) => setTimeout(r, CI_POLL_INTERVAL));
            continue;
          }
          return { content: [{ type: "text", text: `Pipeline status: ${ci.status}\n${ci.detail}` }], details: {} };
        }
        return { content: [{ type: "text", text: "Pipeline still running after max polling time. Check manually." }], details: {} };
      }

      const ci = await checkGH();
      if (ci.status === "success") return { content: [{ type: "text", text: `✅ Pipeline PASSED (${ci.name})\n${ci.url}` }], details: {} };
      if (ci.status === "failure") {
        const logs = await runCmd("gh", ["run", "view", String(ci.runId), "--log-failed"], cwd);
        return { content: [{ type: "text", text: `❌ Pipeline FAILED (${ci.name})\n${ci.url}\n\n${logs.out.slice(-3000)}` }], details: {} };
      }
      return { content: [{ type: "text", text: `Pipeline status: ${ci.status}\n${ci.detail}` }], details: {} };
    },
  });
}
