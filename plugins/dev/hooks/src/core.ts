import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";

export interface ToolCall {
  id?: string;
  name: string;
  args: string | Record<string, any>;
}

export interface PreToolInput {
  cwd?: string;
  toolCalls?: ToolCall[];
  tool_name?: string;
  tool_input?: Record<string, any>;
}

export interface PreToolOutput {
  permissionDecision?: "allow" | "deny";
  permissionDecisionReason?: string;
  decision?: "allow" | "deny" | "block";
  reason?: string;
  modifiedArgs?: Record<string, any>;
  additionalContext?: string;
}

export interface PostToolInput {
  cwd?: string;
  toolName?: string;
  toolInput?: Record<string, any>;
  toolArgs?: Record<string, any>;
  toolResult?: {
    textResultForLlm?: string;
    resultType?: string;
    isError?: boolean | string;
    [key: string]: any;
  };
}

export interface PostToolOutput {
  modifiedResult?: {
    textResultForLlm?: string;
    resultType?: string;
    [key: string]: any;
  };
  additionalContext?: string;
}

export interface SessionStartInput {
  cwd?: string;
  timestamp?: number;
  source?: string;
}

export interface SessionStartOutput {
  additionalContext?: string;
}

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
