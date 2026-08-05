import path from "path"
import type { Plugin, Config } from "@opencode-ai/plugin"

interface PluginConfig extends Config {
  skills?: { paths?: string[] }
}

const PLUGIN_ROOT = path.resolve(import.meta.dir, "../..")
const SKILLS_DIR = path.resolve(PLUGIN_ROOT, "skills")

const editorPlugin: Plugin = async () => {
  return {
    config: async (cfg) => {
      const c = cfg as PluginConfig

      c.skills ??= {}
      c.skills.paths ??= []
      if (!c.skills.paths.includes(SKILLS_DIR)) c.skills.paths.push(SKILLS_DIR)
    },
  }
}

export default editorPlugin
