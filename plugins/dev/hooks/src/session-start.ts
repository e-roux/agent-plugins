import { readFileSync, existsSync, mkdirSync, appendFileSync } from "node:fs";
import { join, basename } from "node:path";
import { execSync } from "node:child_process";
import type { SessionStartInput, SessionStartOutput } from "./types.ts";

export function runSessionStart(input: SessionStartInput): SessionStartOutput {
  const cwd = input.cwd || ".";

  let ctx = "## Dev Guards Active\n\n";
  ctx += "General-purpose guards are enforced:\n";
  ctx += "- **secrets-guard**: no hardcoded credentials — use env vars\n";
  ctx += "- **no-comments-guard**: code must be self-documenting — no comment lines in source files\n";
  ctx += "- **branch-guard**: never push/merge to `main` directly — use PRs\n";
  ctx += "- **migration-guard**: no DROP/TRUNCATE/DELETE in SQL migrations\n";
  ctx += "- **no-verify-guard**: `--no-verify` is forbidden on commits\n";
  ctx += "- **branch-first-guard**: `edit`/`create` on `main`/`master` is blocked — create a feature branch first\n";
  ctx += "- **qa-gate-guard**: `git commit` is BLOCKED unless `make qa` passes with zero errors. Warnings MUST be fixed when feasible — never silently ignore them\n";
  ctx += "- **pipeline-chainguard**: after every `git push`, check CI pipeline status before continuing\n\n";

  ctx += "**MANDATORY WORKFLOW — before editing any file in a git repo:**\n";
  ctx += "1. Check current branch: `git branch --show-current`\n";
  ctx += "2. If on `main`/`master`, create and switch to a feature branch: `git checkout -b <type>/<descriptive-slug>`\n";
  ctx += "3. Only then begin making changes\n\n";
  ctx += "All guards apply to every project in this session.\n\n";

  const memoryDir = join(cwd, ".agents", "memory");
  const reqsDir = join(cwd, "doc", "requirements");

  const hasMemory = existsSync(memoryDir);
  const hasRequirements = existsSync(reqsDir);

  if (!hasMemory && !hasRequirements) {
    ctx += "## Project Memory — Not Yet Configured\n\n";
    ctx += "This project does not have persistent agent memory.\n";
    ctx += "If the user asks to add **requirements**, **specifications**, **pitfalls**, or **lessons learned**, ";
    ctx += "create the directory structure:\n\n";
    ctx += "- Requirements → `doc/requirements/features/<name>.md`\n";
    ctx += "- Pitfalls → `.agents/memory/known-pitfalls.md`\n";
    ctx += "- Lessons → `.agents/memory/lessons/<slug>.md`\n\n";
    ctx += "**NEVER store requirements or specs in session state files.** They must be version-controlled in the project.\n";
  } else {
    ctx += "## Project Memory — Active\n\n";

    if (hasMemory) {
      ctx += "### Pitfalls & Lessons\n\n";
      const pitfallsFile = join(memoryDir, "known-pitfalls.md");
      if (existsSync(pitfallsFile)) {
        try {
          ctx += readFileSync(pitfallsFile, "utf-8") + "\n\n";
        } catch {}
      }

      const lessonsDir = join(memoryDir, "lessons");
      if (existsSync(lessonsDir)) {
        try {
          // List markdown files recursively
          const findOut = execSync(`find "${lessonsDir}" -name '*.md' -type f`, {
            encoding: "utf-8",
            stdio: ["ignore", "pipe", "ignore"],
          }).trim();
          if (findOut) {
            ctx += "**Lessons directory** contains:\n";
            for (const f of findOut.split("\n")) {
              if (f) ctx += `  - ${basename(f, ".md")}\n`;
            }
          }
        } catch {}
      }
      ctx += "\n";
    }

    if (hasRequirements) {
      ctx += "### Feature Requirements\n\n";
      ctx += "Existing requirement specs:\n";
      try {
        const findOut = execSync(`find "${reqsDir}" -name '*.md' -type f`, {
          encoding: "utf-8",
          stdio: ["ignore", "pipe", "ignore"],
        }).trim();
        if (findOut) {
          for (const f of findOut.split("\n")) {
            if (f) {
              const rel = f.startsWith(cwd) ? f.slice(cwd.length + 1) : f;
              ctx += `  - \`${rel}\`\n`;
            }
          }
        } else {
          ctx += "  (none yet)\n";
        }
      } catch {
        ctx += "  (none yet)\n";
      }
      ctx += "\nWhen adding new requirements: `doc/requirements/features/<name>.md`\n";
    }

    ctx += "\n**RULES:**\n";
    ctx += "- Requirements and specs → `doc/requirements/features/<name>.md` (NEVER session state)\n";
    ctx += "- Pitfalls → `.agents/memory/known-pitfalls.md`\n";
    ctx += "- Lessons → `.agents/memory/lessons/<slug>.md`\n";
    ctx += "- Read existing pitfalls BEFORE making changes\n";
    ctx += "- Read relevant requirement specs BEFORE implementing features\n";
  }

  // Write log
  try {
    const pluginRoot = process.env.COPILOT_PLUGIN_ROOT || process.env.CLAUDE_PLUGIN_ROOT || ".";
    const logDir = join(pluginRoot, "hooks", "logs");
    if (!existsSync(logDir)) {
      mkdirSync(logDir, { recursive: true });
    }
    const logFile = join(logDir, "session-start.log");
    const dateStr = new Date().toISOString();
    appendFileSync(logFile, `session-start fired at ${dateStr}, cwd=${cwd}\n`, "utf-8");
  } catch {}

  return { additionalContext: ctx };
}

// CLI Execution entry point if run directly
if (import.meta.main) {
  try {
    const inputStr = readFileSync(0, "utf-8");
    const input: SessionStartInput = JSON.parse(inputStr);
    const result = runSessionStart(input);
    console.log(JSON.stringify(result));
  } catch (err: any) {
    console.error("Error executing session-start guard:", err);
    process.exit(1);
  }
}
