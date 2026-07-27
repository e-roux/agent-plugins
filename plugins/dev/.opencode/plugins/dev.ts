import path from "path"
import type { Plugin, Config } from "@opencode-ai/plugin"
import { runPreTool } from "@dev/hooks/pre-tool.ts"
import { runPostTool } from "@dev/hooks/post-tool.ts"
import { runPipelineChainguard } from "@dev/hooks/pipeline-chainguard.ts"

interface PluginConfig extends Config {
  skills?: { paths?: string[] }
}

const PLUGIN_ROOT = path.resolve(import.meta.dir, "../..")
const SKILLS_DIR = path.resolve(PLUGIN_ROOT, "skills")

const devPlugin: Plugin = async ({ directory }) => {
  return {
    config: async (cfg) => {
      const c = cfg as PluginConfig

      c.skills ??= {}
      c.skills.paths ??= []
      if (!c.skills.paths.includes(SKILLS_DIR)) c.skills.paths.push(SKILLS_DIR)

      c.mcp ??= {}
      Object.assign(c.mcp, {
        "git-ops": {
          type: "local",
          command: ["bash", "-c", 'exec "${XDG_BIN_HOME:-$HOME/.local/bin}/mcp-git-ops"'],
          enabled: true,
        },
      })

      c.permission ??= {}
      c.permission.bash = {
        ...(typeof c.permission.bash === "object" ? c.permission.bash : {}),
        "python3? *": "deny",
        "pip3? *": "deny",
        "virtualenv *": "deny",
        "git push *main*": "deny",
        "git push *master*": "deny",
        "git commit *--no-verify*": "deny",
        "git push *": "ask",
        "git commit *": "ask",
      }
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
      const out = output as { additionalContext?: string }
      const r1 = runPostTool({
        toolName: input.tool,
        toolInput: input.args,
        toolResult: output,
        cwd: directory,
      })
      if (r1.modifiedResult) Object.assign(output, r1.modifiedResult)
      if (r1.additionalContext) {
        const existing = out.additionalContext ?? ""
        out.additionalContext = [existing, r1.additionalContext].filter(Boolean).join("\n")
      }

      const r2 = runPipelineChainguard({
        toolName: input.tool,
        toolInput: input.args,
        toolResult: output,
        cwd: directory,
      })
      if (r2.additionalContext) {
        const existing = out.additionalContext ?? ""
        out.additionalContext = [existing, r2.additionalContext].filter(Boolean).join("\n")
      }
    },
  }
}

export default devPlugin
