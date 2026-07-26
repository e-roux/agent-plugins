import { execFileSync, execSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";

export const SECRET_PATTERN =
  /(JWT_SECRET|API_KEY|CLIENT_SECRET|OIDC_CLIENT_SECRET|DB_PASS(?:WORD)?|MONGODB_URI|RABBITMQ_URL|PRIVATE_KEY|ACCESS_TOKEN_SECRET|SECRET_KEY|PASSWORD|PASSWD)\s*:?=\s*["'][^"']{8,}["']/;

export const COMMENT_EXTENSIONS = new Set([
  ".go", ".ts", ".tsx", ".js", ".jsx", ".py", ".rs",
  ".java", ".c", ".cpp", ".h", ".cs", ".rb", ".swift", ".kt",
]);

export const TEST_CONFIG_PATTERN =
  /(_test\.(go|ts|js|rs|py)|\.test\.(ts|js)|spec\.(ts|js)|\.example|\.md|\.template|testdata|\.bats|\/test\/)/;

export const TOKEN_PATTERNS: Array<[RegExp, string]> = [
  [/gh[ps]_[a-zA-Z0-9]{36}/g, "[REDACTED_GITHUB_TOKEN]"],
  [/gho_[a-zA-Z0-9]{36}/g, "[REDACTED_GITHUB_OAUTH]"],
  [/AKIA[A-Z0-9]{16}/g, "[REDACTED_AWS_KEY]"],
  [/sk-[a-zA-Z0-9]{32,}/g, "[REDACTED_API_KEY]"],
  [/[0-9a-f]{64,}/g, "[REDACTED_TOKEN]"],
];

const MCP_CB_FILE = "/tmp/.mcp-git-ops-cb";
const MCP_CB_TTL = 300;

export function isTestOrConfig(path: string): boolean {
  return TEST_CONFIG_PATTERN.test(path);
}

export function currentBranch(cwd: string): string {
  try {
    const branch = execFileSync("git", ["rev-parse", "--abbrev-ref", "HEAD"], {
      cwd,
      timeout: 5000,
      encoding: "utf-8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
    if (branch !== "HEAD") return branch;
  } catch {}
  try {
    return execFileSync("git", ["symbolic-ref", "--short", "HEAD"], {
      cwd,
      timeout: 5000,
      encoding: "utf-8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
  } catch {
    return "";
  }
}

export function isProtectedBranch(branch: string): boolean {
  return branch === "main" || branch === "master";
}

export function mcpGitOpsAvailable(): boolean {
  try {
    execFileSync("which", ["mcp-git-ops"], {
      timeout: 3000,
      stdio: ["ignore", "ignore", "ignore"],
    });
  } catch {
    return false;
  }
  if (existsSync(MCP_CB_FILE)) {
    try {
      const tripped = parseInt(readFileSync(MCP_CB_FILE, "utf-8").trim(), 10);
      const age = Math.floor(Date.now() / 1000) - tripped;
      if (age < MCP_CB_TTL) return false;
    } catch {}
  }
  return true;
}

export function redactSecrets(text: string): { redacted: string; found: boolean } {
  let result = text;
  let found = false;
  for (const [pattern, replacement] of TOKEN_PATTERNS) {
    if (pattern.test(result)) {
      result = result.replace(pattern, replacement);
      found = true;
    }
  }
  if (/BEGIN.*PRIVATE KEY/.test(result)) {
    result = result.replace(/-----BEGIN[^-]*PRIVATE KEY-----[\s\S]*?-----END[^-]*PRIVATE KEY-----/g, "[REDACTED_PRIVATE_KEY]");
    found = true;
  }
  return { redacted: result, found };
}

export function isMakefile(name: string): boolean {
  return name === "Makefile" || name === "makefile" || name === "GNUmakefile" || name.endsWith(".mk");
}

export function validateMakefile(content: string): string | null {
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
  // Check for inline annotation ## on target lines (e.g. `target: ## help`)
  // Regex equivalent to: ^[a-zA-Z_.][a-zA-Z_.0-9]*[^#\n]*##
  const inlineHelpRegex = /^[a-zA-Z_.][a-zA-Z_.0-9]*[^#\n]*##/m;
  if (inlineHelpRegex.test(content)) {
    return "Makefile has '##' inline annotations on target lines - Approach B (grep-parsed help) is FORBIDDEN. Use explicit printf entries in the help target instead (Approach A).";
  }
  // Check for qa target
  const qaRegex = /(?:^\.PHONY:[^\n]*\bqa\b|^qa\s*:)/m;
  if (!qaRegex.test(content)) {
    return "Makefile missing required 'qa' target - add a 'qa:' recipe that runs 'check test' as the quality gate (e.g., 'qa: check test').";
  }
  return null;
}

export function validateExistingMakefile(filePath: string, newContent: string): string | null {
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
