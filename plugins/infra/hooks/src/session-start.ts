import { readFileSync } from "node:fs";

export interface SessionStartInput {
  cwd?: string;
}

export interface SessionStartOutput {
  additionalContext?: string;
}

export function runSessionStart(input: SessionStartInput): SessionStartOutput {
  return {
    additionalContext: "## Ansible/Molecule Policy Active\n\nRules enforced by preToolUse hook:\n- `ansible-playbook` requires `--check` (dry-run) before real runs on non-local connections\n- `ansible-galaxy` collection installs must include `--force` to avoid stale cache\n- Always use `make` targets when available: `make test` (molecule), `make lint` (ansible-lint)\n- Molecule tests use Podman driver by default — do not switch to Docker without discussion",
  };
}

if (import.meta.main) {
  try {
    const inputStr = readFileSync(0, "utf-8");
    const input: SessionStartInput = JSON.parse(inputStr);
    const result = runSessionStart(input);
    console.log(JSON.stringify(result));
  } catch (err: any) {
    console.error("Error executing infra session-start guard:", err);
    process.exit(1);
  }
}
