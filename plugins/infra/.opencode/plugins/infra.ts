import path from "path"
import type { Plugin, Config } from "@opencode-ai/plugin"
import { runPreTool } from "@infra/hooks/pre-tool.ts"

interface PluginConfig extends Config {
  skills?: { paths?: string[] }
}

const PLUGIN_ROOT = path.resolve(import.meta.dir, "../..")
const SKILLS_DIR = path.resolve(PLUGIN_ROOT, "skills")

const infraPlugin: Plugin = async ({ directory }) => {
  return {
    config: async (cfg) => {
      const c = cfg as PluginConfig

      c.skills ??= {}
      c.skills.paths ??= []
      if (!c.skills.paths.includes(SKILLS_DIR)) c.skills.paths.push(SKILLS_DIR)
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
