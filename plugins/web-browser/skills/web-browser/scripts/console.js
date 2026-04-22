#!/usr/bin/env node

/**
 * Filter and pretty-print console / error entries from the JSONL log files
 * written by watch.js.  Does NOT require Chrome to be running.
 *
 * Usage:
 *   ./console.js                    # All console + exception entries
 *   ./console.js --errors           # Exceptions + console.error only
 *   ./console.js --level warn       # Filter by level: log|info|warn|error|debug
 *   ./console.js --file <path>      # Specific JSONL file (default: latest)
 *   ./console.js --last N           # Show last N entries (default: all)
 */

import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const LOG_ROOT = join(homedir(), ".cache/agent-web/logs");

function statSafe(p) {
  try { return statSync(p); } catch { return null; }
}

function findLatestFile() {
  if (!existsSync(LOG_ROOT)) return null;
  const dirs = readdirSync(LOG_ROOT)
    .filter((n) => /^\d{4}-\d{2}-\d{2}$/.test(n))
    .map((n) => join(LOG_ROOT, n))
    .filter((p) => statSafe(p)?.isDirectory())
    .sort();
  if (!dirs.length) return null;
  const latestDir = dirs[dirs.length - 1];
  const files = readdirSync(latestDir)
    .filter((n) => n.endsWith(".jsonl"))
    .map((n) => join(latestDir, n))
    .map((p) => ({ path: p, mtime: statSafe(p)?.mtimeMs || 0 }))
    .sort((a, b) => b.mtime - a.mtime);
  return files[0]?.path ?? null;
}

const fileIdx = process.argv.indexOf("--file");
const filePath = fileIdx !== -1 ? process.argv[fileIdx + 1] : findLatestFile();

const errorsOnly = process.argv.includes("--errors");
const levelIdx = process.argv.indexOf("--level");
const levelFilter = levelIdx !== -1 ? process.argv[levelIdx + 1] : null;
const lastIdx = process.argv.indexOf("--last");
const lastN = lastIdx !== -1 ? parseInt(process.argv[lastIdx + 1], 10) : null;

if (!filePath) {
  console.error("✗ No log file found — has watch.js been started?");
  process.exit(1);
}

const RESET = "\x1b[0m";
const RED   = "\x1b[31m";
const YELLOW= "\x1b[33m";
const CYAN  = "\x1b[36m";
const DIM   = "\x1b[2m";

function colour(level) {
  if (level === "error" || level === "exception") return RED;
  if (level === "warning" || level === "warn")    return YELLOW;
  if (level === "info")                           return CYAN;
  return DIM;
}

function formatArgs(args) {
  if (!args?.length) return "";
  return args.map((a) => {
    if (a?.value != null) return String(a.value);
    if (a?.description) return a.description;
    return JSON.stringify(a);
  }).join(" ");
}

function formatStack(stack) {
  if (!stack?.length) return "";
  return "\n" + stack
    .slice(0, 3)
    .map((f) => `    at ${f.functionName || "(anon)"} (${f.url}:${f.lineNumber})`)
    .join("\n");
}

let entries = [];

try {
  const data = readFileSync(filePath, "utf8");
  for (const line of data.split("\n").filter(Boolean)) {
    let e;
    try { e = JSON.parse(line); } catch { continue; }

    if (e.type === "console") {
      const level = e.level || "log";
      if (errorsOnly && level !== "error") continue;
      if (levelFilter && level !== levelFilter) continue;
      entries.push({ ts: e.ts, level, msg: formatArgs(e.args), stack: formatStack(e.stack) });
    } else if (e.type === "exception") {
      if (levelFilter && levelFilter !== "error") continue;
      const msg = e.description || e.text || "exception";
      entries.push({ ts: e.ts, level: "exception", msg, stack: formatStack(e.stack) });
    }
  }
} catch (err) {
  console.error("✗ Failed to read log:", err.message);
  process.exit(1);
}

if (lastN != null) entries = entries.slice(-lastN);

if (!entries.length) {
  console.log("○ No matching entries");
  process.exit(0);
}

for (const e of entries) {
  const c = colour(e.level);
  console.log(`${DIM}${e.ts}${RESET} ${c}[${e.level}]${RESET} ${e.msg}${e.stack ? c + e.stack + RESET : ""}`);
}
console.log(`\n${DIM}${entries.length} entries from ${filePath}${RESET}`);
