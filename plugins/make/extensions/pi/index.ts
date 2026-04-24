import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { readFileSync, existsSync } from "node:fs";
import { basename } from "node:path";

const MAKEFILE_NAMES = new Set(["Makefile", "makefile", "GNUmakefile"]);

function isMakefile(name: string): boolean {
  return MAKEFILE_NAMES.has(name) || name.endsWith(".mk");
}

interface RedirectRule {
  pattern: RegExp;
  label: string;
  target: string;
  makeTarget: string;
}

const REDIRECT_RULES: RedirectRule[] = [
  { pattern: /(^|[;&|]\s*)pytest(\s|$)/, label: "pytest", target: "make test", makeTarget: "test" },
  { pattern: /(^|[;&|]\s*)ruff\s+format(\s|$)/, label: "ruff format", target: "make fmt", makeTarget: "fmt" },
  { pattern: /(^|[;&|]\s*)ruff\s+check(\s|$)/, label: "ruff check", target: "make lint", makeTarget: "lint" },
  { pattern: /(^|[;&|]\s*)go\s+test(\s|$)/, label: "go test", target: "make test", makeTarget: "test" },
  { pattern: /(^|[;&|]\s*)go\s+build(\s|$)/, label: "go build", target: "make build", makeTarget: "build" },
  { pattern: /(^|[;&|]\s*)golangci-lint(\s|$)/, label: "golangci-lint", target: "make lint", makeTarget: "lint" },
  { pattern: /(^|[;&|]\s*)eslint(\s|$)/, label: "eslint", target: "make lint", makeTarget: "lint" },
  { pattern: /(^|[;&|]\s*)biome\s+format(\s|$)/, label: "biome format", target: "make fmt", makeTarget: "fmt" },
  { pattern: /(^|[;&|]\s*)biome\s+lint(\s|$)/, label: "biome lint", target: "make lint", makeTarget: "lint" },
  { pattern: /(^|[;&|]\s*)biome\s+check(\s|$)/, label: "biome check", target: "make check", makeTarget: "check" },
  { pattern: /(^|[;&|]\s*)jest(\s|$)/, label: "jest", target: "make test", makeTarget: "test" },
  { pattern: /(^|[;&|]\s*)vitest(\s|$)/, label: "vitest", target: "make test", makeTarget: "test" },
  { pattern: /(^|[;&|]\s*)bun\s+test(\s|$)/, label: "bun test", target: "make test", makeTarget: "test" },
  { pattern: /(^|[;&|]\s*)black(\s|$)/, label: "black", target: "make fmt", makeTarget: "fmt" },
  { pattern: /(^|[;&|]\s*)mypy(\s|$)/, label: "mypy", target: "make typecheck", makeTarget: "typecheck" },
  { pattern: /(^|[;&|]\s*)tsc(\s|$)/, label: "tsc", target: "make typecheck", makeTarget: "typecheck" },
  { pattern: /(^|[;&|]\s*)(npx\s+)?svelte-check(\s|$)/, label: "svelte-check", target: "make typecheck", makeTarget: "typecheck" },
  { pattern: /(^|[;&|]\s*)npm\s+run\s+test(\s|$)/, label: "npm run test", target: "make test", makeTarget: "test" },
  { pattern: /(^|[;&|]\s*)npm\s+test(\s|$)/, label: "npm test", target: "make test", makeTarget: "test" },
  { pattern: /(^|[;&|]\s*)npm\s+run\s+check(\s|$)/, label: "npm run check", target: "make check", makeTarget: "check" },
  { pattern: /(^|[;&|]\s*)npm\s+run\s+lint(\s|$)/, label: "npm run lint", target: "make lint", makeTarget: "lint" },
  { pattern: /(^|[;&|]\s*)npm\s+run\s+build(\s|$)/, label: "npm run build", target: "make build", makeTarget: "build" },
  { pattern: /(^|[;&|]\s*)npm\s+run\s+dev(\s|$)/, label: "npm run dev", target: "make dev", makeTarget: "dev" },
  { pattern: /(^|[;&|]\s*)npm\s+run\s+format(\s|$|:)/, label: "npm run format", target: "make fmt", makeTarget: "fmt" },
  { pattern: /(^|[;&|]\s*)npx\s+eslint(\s|$)/, label: "npx eslint", target: "make lint", makeTarget: "lint" },
  { pattern: /(^|[;&|]\s*)npx\s+jest(\s|$)/, label: "npx jest", target: "make test", makeTarget: "test" },
  { pattern: /(^|[;&|]\s*)npx\s+vitest(\s|$)/, label: "npx vitest", target: "make test", makeTarget: "test" },
  { pattern: /(^|[;&|]\s*)npx\s+tsc(\s|$)/, label: "npx tsc", target: "make typecheck", makeTarget: "typecheck" },
  { pattern: /(^|[;&|]\s*)npx\s+biome(\s|$)/, label: "npx biome", target: "make check", makeTarget: "check" },
];

const FORBIDDEN_PYTHON = /(^|[;&|]\s*)(python3?|pip3?|virtualenv)(\s|$)/;

function validateMakefileContent(content: string): string | null {
  if (!/^\.SILENT/m.test(content)) return "Makefile missing '.SILENT:' directive.";
  if (!/\.ONESHELL/m.test(content)) return "Makefile missing '.ONESHELL:' directive.";
  if (!/\.DEFAULT_GOAL/m.test(content)) return "Makefile missing '.DEFAULT_GOAL := help' directive.";
  if (/^\t@/m.test(content)) return "Makefile has '@' prefix in recipe lines — redundant with '.SILENT:' and forbidden.";
  if (/^[a-zA-Z_.][a-zA-Z_.0-9]*[^#\n]*##/m.test(content)) return "Makefile has '##' inline annotations — Approach B is forbidden. Use explicit printf in the help target.";
  if (!/(?:^\.PHONY:[^\n]*\bqa\b|^qa\s*:)/m.test(content)) return "Makefile missing required 'qa' target.";
  return null;
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    ctx.ui.notify("🔧 Make-first policy active: use make targets, not direct tool calls", "info");
  });

  pi.on("tool_call", async (event, _ctx) => {
    const tool = event.toolName;
    const input = event.input || {};

    if (tool === "bash") {
      const cmd: string = input.command || "";
      if (!cmd) return;

      for (const rule of REDIRECT_RULES) {
        if (rule.pattern.test(cmd)) {
          return {
            block: true,
            reason: `Redirected \`${rule.label}\` → \`${rule.target}\`. Always use make targets (\`make ${rule.makeTarget}\`) — never call tools directly.`,
          };
        }
      }

      if (FORBIDDEN_PYTHON.test(cmd)) {
        return {
          block: true,
          reason: "Direct python/pip/virtualenv is forbidden. Use uv: uv run <script>, uv add <pkg>, uvx <tool>",
        };
      }
    }

    if (tool === "write") {
      const filePath: string = input.path || "";
      const content: string = input.content || input.file_text || "";
      if (filePath && isMakefile(basename(filePath))) {
        const err = validateMakefileContent(content);
        if (err) return { block: true, reason: err };
      }
    }

    if (tool === "edit") {
      const filePath: string = input.path || "";
      const newStr: string = input.new_str || "";
      const oldStr: string = input.old_str || "";

      if (filePath && isMakefile(basename(filePath))) {
        if (/^\t@/m.test(newStr)) {
          return { block: true, reason: "Adding '@' prefix to recipe lines is forbidden — '.SILENT:' already suppresses echoing." };
        }
        if (/^\.SILENT/m.test(oldStr) && !/\.SILENT/m.test(newStr)) {
          return { block: true, reason: "Removing '.SILENT:' is forbidden." };
        }
        if (/\.ONESHELL/m.test(oldStr) && !/\.ONESHELL/m.test(newStr)) {
          return { block: true, reason: "Removing '.ONESHELL:' is forbidden." };
        }

        if (existsSync(filePath)) {
          const current = readFileSync(filePath, "utf-8");
          if (!/^\.SILENT/m.test(current) && !/\.SILENT/m.test(newStr)) {
            return { block: true, reason: `Makefile at ${filePath} is missing '.SILENT:' — add it before making other edits.` };
          }
          if (!/\.ONESHELL/m.test(current) && !/\.ONESHELL/m.test(newStr)) {
            return { block: true, reason: `Makefile at ${filePath} is missing '.ONESHELL:' — add it before making other edits.` };
          }
          if (!/\.DEFAULT_GOAL/m.test(current) && !/\.DEFAULT_GOAL/m.test(newStr)) {
            return { block: true, reason: `Makefile at ${filePath} is missing '.DEFAULT_GOAL' — add it before making other edits.` };
          }
        }
      }
    }
  });
}
