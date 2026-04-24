import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    ctx.ui.notify("🏗️ Ansible/Molecule policy active: dry-run first, make targets for quality checks", "info");
  });

  pi.on("tool_call", async (event, _ctx) => {
    const tool = event.toolName;
    const input = event.input || {};

    if (tool !== "bash") return;
    const cmd: string = input.command || "";
    if (!cmd) return;

    if (/(^|[;&|]\s*)ansible-playbook\b/.test(cmd)) {
      if (!/--check/.test(cmd) && !/--connection[= ]local/.test(cmd) && !/-c local/.test(cmd)) {
        return {
          block: true,
          reason: "ansible-playbook must use --check (dry-run) first on non-local connections. Run with --check to verify, then remove it for the real run.",
        };
      }
    }

    if (/(^|[;&|]\s*)ansible-lint\b/.test(cmd)) {
      return {
        block: true,
        reason: "Redirected ansible-lint → make lint. Use make targets for all quality checks.",
      };
    }

    if (/(^|[;&|]\s*)molecule\b/.test(cmd)) {
      return {
        block: true,
        reason: "Redirected molecule → make test. Use make targets for all testing.",
      };
    }
  });
}
