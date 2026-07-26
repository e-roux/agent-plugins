import path from "path"
import type { Plugin } from "@opencode-ai/plugin"
import { runPreTool } from "../../hooks/src/pre-tool.ts"

const PLUGIN_ROOT = path.resolve(import.meta.dir, "../..")
const SKILLS_DIR = path.resolve(PLUGIN_ROOT, "skills")

const infraPlugin: Plugin = async ({ directory }) => {
  return {
    config: async (cfg) => {
      const c = cfg as Record<string, unknown>
      const skills = (c.skills ??= {}) as Record<string, unknown>
      const paths = (skills.paths ??= []) as string[]
      if (!paths.includes(SKILLS_DIR)) paths.push(SKILLS_DIR)
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
  }
}

export default infraPlugin
