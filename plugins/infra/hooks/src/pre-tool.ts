import { readFileSync } from "node:fs";
import type { PreToolInput, PreToolOutput } from "@mxhq/agent-plugin-core";

export function runPreTool(input: PreToolInput): PreToolOutput {
  if (!input.toolCalls || input.toolCalls.length === 0) {
    return {};
  }

  for (const toolCall of input.toolCalls) {
    if (toolCall.name === "bash" || toolCall.name === "run_command" || toolCall.name === "execute_command") {
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

      const cmd = args.command || args.commandLine || "";
      if (!cmd) continue;

      // Block ansible-playbook without --check on non-localhost
      if (/(^|[;&|]\s*)ansible-playbook\b/.test(cmd)) {
        const hasCheck = /--check\b/.test(cmd);
        const isLocal = /--connection[= ]local\b|-c local\b/.test(cmd);
        if (!hasCheck && !isLocal) {
          return {
            permissionDecision: "deny",
            permissionDecisionReason: "ansible-playbook must use --check (dry-run) first on non-local connections. Run with --check to verify, then remove it for the real run.",
          };
        }
      }

      // Redirect direct ansible-lint to make lint
      if (/(^|[;&|]\s*)ansible-lint\b/.test(cmd)) {
        return {
          modifiedArgs: { command: "make lint" },
          additionalContext: "Redirected ansible-lint → make lint. Use make targets for all quality checks.",
        };
      }

      // Redirect direct molecule test to make test
      if (/(^|[;&|]\s*)molecule\b/.test(cmd)) {
        return {
          modifiedArgs: { command: "make test" },
          additionalContext: "Redirected molecule → make test. Use make targets for all testing.",
        };
      }
    }
  }

  return {};
}

if (import.meta.main) {
  try {
    const inputStr = readFileSync(0, "utf-8");
    const input: PreToolInput = JSON.parse(inputStr);
    const result = runPreTool(input);
    console.log(JSON.stringify(result));
  } catch (err: any) {
    console.error("Error executing infra pre-tool guard:", err);
    process.exit(1);
  }
}
