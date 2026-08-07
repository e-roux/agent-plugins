import { readFileSync } from "node:fs";
import { currentBranch } from "./core.ts";
import type { SessionStartInput } from "./core.ts";

export function runBranchCheckTurn(input: SessionStartInput): void {
  const cwd = input.cwd || ".";
  const branch = currentBranch(cwd);

  if (!branch || branch === "HEAD") {
    return;
  }

  if (branch === "main" || branch === "master") {
    console.log(`⛔ BRANCH-FIRST GUARD: Current branch is "${branch}" in ${cwd}.`);
    console.log("You MUST create a feature branch before editing any files:");
    console.log("  git checkout -b <type>/<descriptive-slug>");
    console.log("Types: feat/ fix/ chore/ docs/ refactor/ test/");
    console.log("The preToolUse hook will block edit/create/bash-write attempts on this branch.");
  } else {
    console.log(`ℹ️ Branch: ${branch} — good to edit files.`);
  }
}

// CLI Execution entry point if run directly
if (import.meta.main) {
  try {
    const inputStr = readFileSync(0, "utf-8");
    const input: SessionStartInput = JSON.parse(inputStr);
    runBranchCheckTurn(input);
  } catch (err: any) {
    console.error("Error executing branch-check-turn:", err);
    process.exit(1);
  }
}
