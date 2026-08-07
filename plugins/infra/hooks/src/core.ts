import { execFileSync } from "node:child_process";

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

export interface SessionStartInput {
  cwd?: string;
  timestamp?: number;
  source?: string;
}

export interface SessionStartOutput {
  additionalContext?: string;
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
