declare interface ImportMeta {
  readonly dir: string;
  readonly file: string;
}

declare interface OpencodeSkillsConfig {
  paths?: string[]
}

declare interface OpencodePluginConfig {
  skills?: OpencodeSkillsConfig
  mcp?: Record<string, unknown>
  permission?: {
    bash?: Record<string, string> | string
    [key: string]: unknown
  }
}
