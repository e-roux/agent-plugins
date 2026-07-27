import { readFileSync, existsSync } from "node:fs";
import { dirname, basename } from "node:path";
import { execSync } from "node:child_process";
import {
  isTestOrConfig,
  currentBranch,
  isProtectedBranch,
  mcpGitOpsAvailable,
  SECRET_PATTERN,
  COMMENT_EXTENSIONS,
} from "@mxhq/agent-plugin-core";
import type { PreToolInput, PreToolOutput, ToolCall } from "@mxhq/agent-plugin-core";

function isMakefile(name: string): boolean {
  return name === "Makefile" || name === "makefile" || name === "GNUmakefile" || name.endsWith(".mk");
}

function validateMakefile(content: string): string | null {
  if (!content.includes(".SILENT:")) {
    return "Makefile missing required directive: '.SILENT:' - add it before the first target to suppress recipe echoing without @.";
  }
  if (!content.includes(".ONESHELL:")) {
    return "Makefile missing required directive: '.ONESHELL:' - add it to run each recipe in a single shell instance.";
  }
  if (!content.includes(".DEFAULT_GOAL")) {
    return "Makefile missing required directive: '.DEFAULT_GOAL := help' - the default target must be 'help'.";
  }
  if (/\t@/.test(content)) {
    return "Makefile has '@' prefix in recipe lines - this is redundant with '.SILENT:' and FORBIDDEN. Remove all '@' prefixes from recipes.";
  }
  const inlineHelpRegex = /^[a-zA-Z_.][a-zA-Z_.0-9]*[^#\n]*##/m;
  if (inlineHelpRegex.test(content)) {
    return "Makefile has '##' inline annotations on target lines - Approach B (grep-parsed help) is FORBIDDEN. Use explicit printf entries in the help target instead (Approach A).";
  }
  const qaRegex = /(?:^\.PHONY:[^\n]*\bqa\b|^qa\s*:)/m;
  if (!qaRegex.test(content)) {
    return "Makefile missing required 'qa' target - add a 'qa:' recipe that runs 'check test' as the quality gate (e.g., 'qa: check test').";
  }
  return null;
}

function validateExistingMakefile(filePath: string, newContent: string): string | null {
  if (!existsSync(filePath)) return null;
  const current = readFileSync(filePath, "utf-8");
  if (!current.includes(".SILENT:") && !newContent.includes(".SILENT:")) {
    return `Makefile at ${filePath} is missing '.SILENT:' - add this directive before making other edits.`;
  }
  if (!current.includes(".ONESHELL:") && !newContent.includes(".ONESHELL:")) {
    return `Makefile at ${filePath} is missing '.ONESHELL:' - add this directive before making other edits.`;
  }
  if (!current.includes(".DEFAULT_GOAL") && !newContent.includes(".DEFAULT_GOAL")) {
    return `Makefile at ${filePath} is missing '.DEFAULT_GOAL' - add this directive before making other edits.`;
  }
  return null;
}

function deny(reason: string): PreToolOutput {
  return {
    permissionDecision: "deny",
    permissionDecisionReason: reason,
  };
}

function redirect(cmd: string, replacement: string, target: string): PreToolOutput {
  return {
    modifiedArgs: { command: replacement },
    additionalContext: `Redirected \`${cmd}\` -> \`${replacement}\`. Always use make targets (\`make ${target}\`) - never call tools directly.`,
  };
}

function processToolCall(toolCall: ToolCall, cwd: string): PreToolOutput | null {
  const toolName = toolCall.name;
  let args: Record<string, any> = {};

  if (typeof toolCall.args === "string") {
    try {
      args = JSON.parse(toolCall.args);
    } catch {
      args = {};
    }
  } else if (toolCall.args && typeof toolCall.args === "object") {
    args = toolCall.args;
  }

  // 1. Edit / Create tools
  if (toolName === "edit" || toolName === "create" || toolName === "write") {
    const filePath = args.filePath || args.path || args.file_path || "";
    const newContent = args.newString || args.new_str || args.file_text || args.content || "";

    if (filePath) {
      const base = basename(filePath);

      // Makefile validation
      if (isMakefile(base) && !/\/tmp\/|\/private\/tmp\/|\/var\/folders\//.test(filePath)) {
        if (toolName === "create") {
          const err = validateMakefile(newContent);
          if (err) return deny(err);
        } else {
          // Check if adding @ prefix
          if (/^\t@/m.test(newContent)) {
            return deny("Adding '@' prefix to recipe lines is FORBIDDEN - '.SILENT:' already suppresses echoing. Remove the '@' prefix.");
          }
          const oldContent = args.oldString || args.old_str || "";
          if (oldContent.includes(".SILENT:") && !newContent.includes(".SILENT:")) {
            return deny("Removing '.SILENT:' from the Makefile is FORBIDDEN - it is a required directive.");
          }
          if (oldContent.includes(".ONESHELL:") && !newContent.includes(".ONESHELL:")) {
            return deny("Removing '.ONESHELL:' from the Makefile is FORBIDDEN - it is a required directive.");
          }
          const err = validateExistingMakefile(filePath, newContent);
          if (err) return deny(err);
        }
      }

      // Secrets validation (non-test files)
      if (!isTestOrConfig(filePath)) {
        if (SECRET_PATTERN.test(newContent)) {
          return deny(`Secrets guard: potential hardcoded credential detected in ${base}. Use os.Getenv() / process.env / env vars instead.`);
        }
      }

      // No-comments validation
      if (!isTestOrConfig(filePath)) {
        const ext = filePath.match(/\.[^./]+$/)?.[0] || "";
        if (COMMENT_EXTENSIONS.has(ext)) {
          // Check for line comments or block comments
          if (/^[ \t]*(\/\/|\/\*|\*\/)/m.test(newContent)) {
            return deny("No-comments guard: code must be self-documenting - express intent through clear naming, not comment lines. See https://p.ampeco.com/infinite-engineer/infinite-engineer");
          }

          // Stripping lines between # ///
          const lines = newContent.split("\n");
          let skip = false;
          const strippedLines: string[] = [];
          for (const line of lines) {
            if (/^[ \t]*# \/\/\//.test(line)) {
              skip = !skip;
              continue;
            }
            if (skip) continue;
            strippedLines.push(line);
          }

          const hasHashComment = strippedLines.some(
            (l) => /^[ \t]*#/.test(l) && !/^[ \t]*(#!|# noqa)/.test(l)
          );
          if (hasHashComment) {
            return deny("No-comments guard: code must be self-documenting - express intent through clear naming, not comment lines. See https://p.ampeco.com/infinite-engineer/infinite-engineer");
          }
        }
      }

      // Branch-first check on edit/create
      if (!isTestOrConfig(filePath)) {
        const fileDir = dirname(filePath);
        const checkDir = existsSync(fileDir) ? fileDir : cwd;
        const branch = currentBranch(checkDir);
        if (isProtectedBranch(branch)) {
          return deny(`Branch-first guard: you are on '${branch}'. Create a feature branch first: git checkout -b <type>/<descriptive-slug>`);
        }
      }
    }
  }

  // 2. Bash execution tool
  if (toolName === "bash" || toolName === "run_command" || toolName === "execute_command") {
    const cmd = args.command || args.commandLine || "";
    if (cmd) {
      const matchesCmd = (pattern: string) => {
        const regex = new RegExp(`(^|[;&|][\\s]*)${pattern}([\\s]|$)`);
        return regex.test(cmd);
      };

      // Redirect check for common tools
      if (matchesCmd("pytest")) return redirect(cmd, "make test", "test");
      if (/(^|[;&|]\s*)ruff\s+format([\s]|$)/.test(cmd)) return redirect(cmd, "make fmt", "fmt");
      if (/(^|[;&|]\s*)ruff\s+check([\s]|$)/.test(cmd)) return redirect(cmd, "make lint", "lint");
      if (/(^|[;&|]\s*)go\s+test([\s]|$)/.test(cmd)) return redirect(cmd, "make test", "test");
      if (/(^|[;&|]\s*)go\s+build([\s]|$)/.test(cmd)) return redirect(cmd, "make build", "build");
      if (matchesCmd("golangci-lint")) return redirect(cmd, "make lint", "lint");
      if (matchesCmd("eslint")) return redirect(cmd, "make lint", "lint");
      if (/(^|[;&|]\s*)biome\s+format([\s]|$)/.test(cmd)) return redirect(cmd, "make fmt", "fmt");
      if (/(^|[;&|]\s*)biome\s+lint([\s]|$)/.test(cmd)) return redirect(cmd, "make lint", "lint");
      if (/(^|[;&|]\s*)biome\s+check([\s]|$)/.test(cmd)) return redirect(cmd, "make check", "check");
      if (matchesCmd("jest")) return redirect(cmd, "make test", "test");
      if (matchesCmd("vitest")) return redirect(cmd, "make test", "test");
      if (/(^|[;&|]\s*)bun\s+test([\s]|$)/.test(cmd)) return redirect(cmd, "make test", "test");
      if (matchesCmd("black")) return redirect(cmd, "make fmt", "fmt");

      // Python / pip block
      if (/(^|[;&|]\s*)(python3?|pip3?|virtualenv)([\s]|$)/.test(cmd)) {
        return deny("Direct python/pip/virtualenv is forbidden. Use uv: uv run <script>, uv add <pkg>, uvx <tool>");
      }

      if (/(^|[;&|]\s*)mypy([\s]|$)/.test(cmd)) return redirect(cmd, "make typecheck", "typecheck");
      if (/(^|[;&|]\s*)tsc([\s]|$)/.test(cmd)) return redirect(cmd, "make typecheck", "typecheck");
      if (matchesCmd("svelte-check") || /(^|[;&|]\s*)npx\s+svelte-check([\s]|$)/.test(cmd)) {
        return redirect(cmd, "make typecheck", "typecheck");
      }

      // npm run check mappings
      if (/(^|[;&|]\s*)npm\s+run\s+test([\s]|$)/.test(cmd)) return redirect(cmd, "npm run test", "test");
      if (/(^|[;&|]\s*)npm\s+test([\s]|$)/.test(cmd)) return redirect(cmd, "npm test", "test");
      if (/(^|[;&|]\s*)npm\s+run\s+check([\s]|$)/.test(cmd)) return redirect(cmd, "npm run check", "check");
      if (/(^|[;&|]\s*)npm\s+run\s+lint([\s]|$)/.test(cmd)) return redirect(cmd, "npm run lint", "lint");
      if (/(^|[;&|]\s*)npm\s+run\s+build([\s]|$)/.test(cmd)) return redirect(cmd, "npm run build", "build");
      if (/(^|[;&|]\s*)npm\s+run\s+dev([\s]|$)/.test(cmd)) return redirect(cmd, "npm run dev", "dev");
      if (/(^|[;&|]\s*)npm\s+run\s+format([\s:]|$)/.test(cmd)) return redirect(cmd, "npm run format", "fmt");
      if (/(^|[;&|]\s*)npx\s+eslint([\s]|$)/.test(cmd)) return redirect(cmd, "npx eslint", "lint");
      if (/(^|[;&|]\s*)npx\s+jest([\s]|$)/.test(cmd)) return redirect(cmd, "npx jest", "test");
      if (/(^|[;&|]\s*)npx\s+vitest([\s]|$)/.test(cmd)) return redirect(cmd, "npx vitest", "test");
      if (/(^|[;&|]\s*)npx\s+tsc([\s]|$)/.test(cmd)) return redirect(cmd, "npx tsc", "typecheck");
      if (/(^|[;&|]\s*)npx\s+biome([\s]|$)/.test(cmd)) return redirect(cmd, "npx biome", "check");

      // mcp-git-ops blocks
      if (/git\s+push\b/.test(cmd) && mcpGitOpsAvailable()) {
        return deny("Use the mcp__git-ops__push tool instead of bash git push. It enforces branch protection and triggers CI monitoring. If MCP failed previously, retry in a moment - the circuit breaker will allow bash through.");
      }
      if (/(gh\s+pr\s+create|glab\s+mr\s+create|az\s+repos\s+pr\s+create)\b/.test(cmd) && mcpGitOpsAvailable()) {
        return deny("Use the mcp__git-ops__create_pr tool instead. It auto-detects the platform and enforces branch protection.");
      }
      if (/(gh\s+pr\s+merge|glab\s+mr\s+merge|az\s+repos\s+pr\s+update.*--status\s+completed)\b/.test(cmd) && mcpGitOpsAvailable()) {
        return deny("Use the mcp__git-ops__merge_pr tool instead. It auto-detects the platform.");
      }

      // Output redirection check on protected branches
      if (/(>[ \t]+[^/dev]|>>[ \t]+[^/dev]|[ \t]tee[ \t][^-]|sed[ \t]+-[^ ]*i)/.test(cmd)) {
        const branch = currentBranch(cwd);
        if (isProtectedBranch(branch)) {
          return deny(`Branch-first guard: you are on '${branch}'. Create a feature branch first: git checkout -b <type>/<descriptive-slug>`);
        }
      }

      // Destruction migration check
      if (/migrations?\/|\.sql/i.test(cmd)) {
        if (/(DROP\s+(TABLE|COLUMN|SCHEMA)|TRUNCATE\s+TABLE|DELETE\s+FROM)/i.test(cmd)) {
          return deny("Migration guard: destructive SQL (DROP/TRUNCATE/DELETE) is forbidden in migrations. Use additive changes only (ADD COLUMN, CREATE TABLE).");
        }
      }

      // Tag validation (CHANGELOG checks)
      if (/git\s+tag\b/.test(cmd)) {
        const rawVersionMatch = cmd.match(/([a-zA-Z0-9_-]+\/)?v[0-9]+\.[0-9]+\.[0-9]+([-.][a-zA-Z0-9]+)?/);
        if (rawVersionMatch) {
          const rawVersion = rawVersionMatch[0];
          const versionMatch = rawVersion.match(/v[0-9]+\.[0-9]+\.[0-9]+([-.][a-zA-Z0-9]+)?/);
          const version = versionMatch ? versionMatch[0] : "";
          const pluginMatch = rawVersion.match(/^[^/]+/);
          const plugin = (pluginMatch && !/^v[0-9]/.test(pluginMatch[0])) ? pluginMatch[0] : "";

          let changelogPath = `${cwd}/CHANGELOG.md`;
          if (plugin && existsSync(`${cwd}/plugins/${plugin}/CHANGELOG.md`)) {
            changelogPath = `${cwd}/plugins/${plugin}/CHANGELOG.md`;
          }

          if (!existsSync(changelogPath)) {
            return deny(`Changelog guard: CHANGELOG.md not found for plugin '${plugin}' - create it with an [Unreleased] section via a release PR before tagging.`);
          }

          const changelogContent = readFileSync(changelogPath, "utf-8");
          const hasHeading = new RegExp(`^## \\[${version}\\]|^## \\[${version.slice(1)}\\]`, "m").test(changelogContent);
          if (!hasHeading) {
            return deny(`Changelog guard: ${version} not found as a heading in changelog: ${changelogPath} - update it with a [${version}] section via a release PR before tagging.`);
          }
        }
      }

      // git commit QA gate
      if (/git\s+commit\b/.test(cmd)) {
        if (existsSync(`${cwd}/Makefile`)) {
          try {
            const qaOut = execSync("make qa", {
              cwd,
              encoding: "utf-8",
              stdio: ["ignore", "pipe", "pipe"],
            });
            return {
              additionalContext: `QA gate passed. Output:\n\`\`\`\n${qaOut.trim()}\n\`\`\`\n\nWarnings MUST be fixed when feasible - do not ignore them.`,
            };
          } catch (e: any) {
            const errorOutput = e.stdout || e.stderr || e.message || "";
            return deny(`QA gate: make qa failed - fix ALL errors before committing. Zero failures required, regardless of error origin.\n\n${errorOutput.trim()}`);
          }
        }
      }

      // Prevent direct main push/merge
      if (/git\s+(push|merge)\s+[^&|;]*\b(main|master)\b/.test(cmd)) {
        return deny("Branch guard: never push/merge to main directly. Use a PR: gh pr create --base <default-branch>.");
      }

      // Block --no-verify bypass
      if (/git\s+commit\s+.*--no-verify/.test(cmd)) {
        return deny("Branch guard: --no-verify bypasses commit hooks. Remove the flag.");
      }
    }
  }

  return null;
}

export function runPreTool(input: PreToolInput): PreToolOutput {
  const cwd = input.cwd || ".";
  if (input.toolCalls && input.toolCalls.length > 0) {
    for (const toolCall of input.toolCalls) {
      const decision = processToolCall(toolCall, cwd);
      if (decision) {
        return decision;
      }
    }
  }
  return {};
}

// CLI Execution entry point if run directly
if (import.meta.main) {
  try {
    const inputStr = readFileSync(0, "utf-8");
    const input: PreToolInput = JSON.parse(inputStr);
    const result = runPreTool(input);
    if (Object.keys(result).length > 0) {
      console.log(JSON.stringify(result));
    }
  } catch (err: any) {
    console.error("Error executing pre-tool guard:", err);
    process.exit(1);
  }
}
