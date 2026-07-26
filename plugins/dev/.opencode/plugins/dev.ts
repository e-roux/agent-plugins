import path from "path"
import type { Plugin } from "@opencode-ai/plugin"
import { runPreTool } from "../../hooks/src/pre-tool.ts"
import { runPostTool } from "../../hooks/src/post-tool.ts"
import { runPipelineChainguard } from "../../hooks/src/pipeline-chainguard.ts"

const PLUGIN_ROOT = path.resolve(import.meta.dir, "../..")
const SKILLS_DIR = path.resolve(PLUGIN_ROOT, "skills")

const devPlugin: Plugin = async ({ directory }) => {
  return {
    config: async (cfg) => {
      const c = cfg as Record<string, unknown>
      const skills = (c.skills ??= {}) as Record<string, unknown>
      const paths = (skills.paths ??= []) as string[]
      if (!paths.includes(SKILLS_DIR)) paths.push(SKILLS_DIR)

      const mcp = (c.mcp ??= {}) as Record<string, unknown>
      Object.assign(mcp, {
        "git-ops": {
          type: "local",
          command: ["bash", "-c", 'exec "${XDG_BIN_HOME:-$HOME/.local/bin}/mcp-git-ops"'],
          enabled: true,
        },
      })

      const perm = (c.permission ??= {}) as Record<string, unknown>
      const bashPerm = (perm.bash ??= {}) as Record<string, string>
      Object.assign(bashPerm, {
        "python3? *": "deny",
        "pip3? *": "deny",
        "virtualenv *": "deny",
        "git push *main*": "deny",
        "git push *master*": "deny",
        "git commit *--no-verify*": "deny",
        "git push *": "ask",
        "git commit *": "ask",
      })
    },

    "tool.execute.before": async (input, output) => {
      const r = runPreTool({
        toolCalls: [{ name: input.tool, args: output.args }],
        cwd: directory,
      })
      if (r.permissionDecision === "deny") {
        throw new Error(r.permissionDecisionReason || "Denied by guard")
      }
      if (r.modifiedArgs) Object.assign(output.args, r.modifiedArgs)
    },

    "tool.execute.after": async (input, output) => {
      const out = output as Record<string, any>
      const r1 = runPostTool({
        toolName: input.tool,
        toolInput: input.args,
        toolResult: output,
        cwd: directory,
      })
      if (r1.modifiedResult) Object.assign(output, r1.modifiedResult)
      if (r1.additionalContext) {
        const existing = (out.additionalContext as string) ?? ""
        out.additionalContext = [existing, r1.additionalContext].filter(Boolean).join("\n")
      }

      const r2 = runPipelineChainguard({
        toolName: input.tool,
        toolInput: input.args,
        toolResult: output,
        cwd: directory,
      })
      if (r2.additionalContext) {
        const existing = (out.additionalContext as string) ?? ""
        out.additionalContext = [existing, r2.additionalContext].filter(Boolean).join("\n")
      }
    },
  }
}

export default devPlugin
