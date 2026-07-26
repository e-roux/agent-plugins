import { readFileSync, writeFileSync } from "node:fs";
import { redactSecrets } from "./utils.ts";
import type { PostToolInput, PostToolOutput } from "./types.ts";

const MCP_CB_FILE = "/tmp/.mcp-git-ops-cb";

export function runPostTool(input: PostToolInput): PostToolOutput {
  const toolName = input.toolName || "";
  const toolResult = input.toolResult || {};
  const toolInput = input.toolInput || {};

  // 1. MCP git-ops circuit breaker
  if (toolName.startsWith("mcp__git-ops__")) {
    const resultType = toolResult.resultType || "";
    const isError = toolResult.isError === true || String(toolResult.isError) === "true";
    const textResult = toolResult.textResultForLlm || JSON.stringify(toolResult);

    if (
      resultType === "error" ||
      isError ||
      /denied|failed|error|cannot/i.test(textResult)
    ) {
      try {
        const now = Math.floor(Date.now() / 1000);
        writeFileSync(MCP_CB_FILE, String(now), "utf-8");
      } catch {}
    }
    return {};
  }

  if (toolName !== "bash") {
    return {};
  }

  const resultText = toolResult.textResultForLlm || "";
  if (!resultText) {
    return {};
  }

  const cmdInput = toolInput.command || "";
  let additionalContext = "";

  // Secrets redaction
  const { redacted, found } = redactSecrets(resultText);

  // Release reminder check
  if (cmdInput && /git\s+tag\b.*v[0-9]/.test(cmdInput)) {
    const resultType = toolResult.resultType || "";
    if (resultType !== "error") {
      const tagMatch = cmdInput.match(/v[0-9]+\.[0-9]+\.[0-9]+([-.][a-zA-Z0-9]+)?/);
      const tagRef = tagMatch ? tagMatch[0] : "<tag>";
      additionalContext = `Tag ${tagRef} created locally. Next steps:
1. Push the tag: git push origin ${tagRef}
2. Build artifacts if applicable: make release
3. Create platform release: use mcp__git-ops__create_release (preferred) or gh/glab release create
   See the git-release skill resource for the complete workflow and capability-based enhancements.`;
    }
  }

  const output: PostToolOutput = {};

  if (found) {
    output.modifiedResult = {
      textResultForLlm: redacted,
      resultType: "success",
    };
    output.additionalContext = additionalContext
      ? `${additionalContext}\n\n⚠️ Secrets were detected and redacted from tool output. Never include credentials in code or commit messages.`
      : "⚠️ Secrets were detected and redacted from tool output. Never include credentials in code or commit messages.";
  } else if (additionalContext) {
    output.additionalContext = additionalContext;
  }

  return output;
}

// CLI Execution entry point if run directly
if (import.meta.main) {
  try {
    const inputStr = readFileSync(0, "utf-8");
    const input: PostToolInput = JSON.parse(inputStr);
    const result = runPostTool(input);
    if (Object.keys(result).length > 0) {
      console.log(JSON.stringify(result));
    }
  } catch (err: any) {
    console.error("Error executing post-tool guard:", err);
    process.exit(1);
  }
}
