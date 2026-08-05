#!/usr/bin/env node
/**
 * Storybook story checker — visits every story in the Storybook UI
 * and reports any stories that show an error, warning, or fail to render.
 *
 * Usage: node check-stories.mjs [--fast] [--filter <group>]
 *   --fast   Reduce wait time to 1.5s per story (default 2.5s)
 *   --filter Prefix filter e.g. "shared-" to only check matching stories
 */
import WebSocket from "ws";

const STORYBOOK = "http://localhost:6007";
const FAST = process.argv.includes("--fast");
const FILTER = (() => {
  const i = process.argv.indexOf("--filter");
  return i >= 0 ? process.argv[i + 1] : null;
})();
const WAIT_MS = FAST ? 1200 : 2000;

// ── CDP plumbing ──────────────────────────────────────────────────────────────

async function connectCDP(timeout = 6000) {
  const r = await fetch("http://localhost:9222/json/version");
  const { webSocketDebuggerUrl } = await r.json();
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(webSocketDebuggerUrl);
    const t = setTimeout(() => reject(new Error("WS connect timeout")), timeout);
    ws.on("open", () => { clearTimeout(t); resolve(ws); });
    ws.on("error", (e) => { clearTimeout(t); reject(e); });
  });
}

let cmdId = 1;
function send(ws, method, params = {}, sessionId) {
  const id = cmdId++;
  const msg = { id, method, params };
  if (sessionId) msg.sessionId = sessionId;
  return new Promise((resolve, reject) => {
    const handler = (data) => {
      const m = JSON.parse(data);
      if (m.id !== id) return;
      ws.off("message", handler);
      if (m.error) reject(new Error(m.error.message)); else resolve(m.result);
    };
    ws.on("message", handler);
    ws.send(JSON.stringify(msg));
  });
}

async function getActiveTab(ws) {
  const { targetInfos } = await send(ws, "Target.getTargets");
  const pages = targetInfos.filter(t => t.type === "page" && !t.url.startsWith("devtools://"));
  return pages.at(-1);
}

async function attachSession(ws, targetId) {
  const { sessionId } = await send(ws, "Target.attachToTarget", { targetId, flatten: true });
  return sessionId;
}

async function navigate(ws, sessionId, url) {
  await send(ws, "Page.navigate", { url }, sessionId);
  await new Promise(resolve => setTimeout(resolve, WAIT_MS));
}

async function evalInPage(ws, sessionId, expression) {
  const result = await send(ws, "Runtime.evaluate", {
    expression,
    returnByValue: true,
    awaitPromise: false,
  }, sessionId);
  return result?.result?.value;
}

// ── Story list ────────────────────────────────────────────────────────────────

async function getStories() {
  const r = await fetch(`${STORYBOOK}/index.json`);
  const data = await r.json();
  return Object.entries(data.entries || {})
    .filter(([, v]) => v.type === "story")
    .map(([id]) => id)
    .filter(id => !FILTER || id.startsWith(FILTER))
    .sort();
}

// ── Error detection ───────────────────────────────────────────────────────────

async function checkStory(ws, sessionId, storyId) {
  const url = `${STORYBOOK}/iframe.html?id=${storyId}&viewMode=story`;
  await navigate(ws, sessionId, url);

  const issues = [];

  // Error display is display:none when story is healthy; height>0 means real error
  const errVisible = await evalInPage(ws, sessionId,
    `document.querySelector(".sb-errordisplay")?.getBoundingClientRect().height > 0`
  );
  if (errVisible) {
    const errorText = await evalInPage(ws, sessionId,
      `(document.querySelector(".sb-errordisplay")?.textContent || "").trim().substring(0,300)`
    );
    issues.push({ type: "error", message: errorText || "Error boundary triggered" });
  }

  // Check for unhandled JS errors visible in body text
  const bodyText = await evalInPage(ws, sessionId, `document.body?.textContent?.substring(0,300) || ""`);
  if (bodyText && (
    bodyText.includes("Uncaught SyntaxError") ||
    bodyText.includes("Uncaught ReferenceError") ||
    bodyText.includes("Uncaught TypeError") ||
    bodyText.includes("Failed to fetch")
  )) {
    issues.push({ type: "error", message: bodyText.substring(0, 200).trim() });
  }

  // Check story root rendered anything meaningful  
  // (some stories legitimately render visually empty but have DOM nodes)
  const rootHtml = await evalInPage(ws, sessionId,
    `document.getElementById("storybook-root")?.innerHTML?.trim() || ""`
  );
  if (!rootHtml || rootHtml === "<!---->") {
    issues.push({ type: "warn", message: "Story root is completely empty" });
  }

  return issues;
}

// ── Main ──────────────────────────────────────────────────────────────────────

const ws = await connectCDP();
const tab = await getActiveTab(ws);
if (!tab) { console.error("No browser tab found"); process.exit(1); }
const sessionId = await attachSession(ws, tab.targetId);
await send(ws, "Page.enable", {}, sessionId);
await send(ws, "Runtime.enable", {}, sessionId);

const stories = await getStories();
console.log(`Checking ${stories.length} stories (WAIT=${WAIT_MS}ms each)…\n`);

const errors = [];
const warnings = [];
let checked = 0;

for (const storyId of stories) {
  checked++;
  process.stdout.write(`[${String(checked).padStart(3)}/${stories.length}] ${storyId.padEnd(70)}\r`);

  try {
    const issues = await checkStory(ws, sessionId, storyId);
    const storyErrors = issues.filter(i => i.type === "error");
    const storyWarns = issues.filter(i => i.type === "warn");

    if (storyErrors.length > 0) {
      errors.push({ story: storyId, issues: storyErrors });
      process.stdout.write(`\n❌ ${storyId}\n`);
      storyErrors.forEach(e => process.stdout.write(`   ${e.message}\n`));
    } else if (storyWarns.length > 0) {
      warnings.push({ story: storyId, issues: storyWarns });
      process.stdout.write(`\n⚠️  ${storyId} — ${storyWarns.map(w=>w.message).join("; ")}\n`);
    } else {
      process.stdout.write(`\n✅ ${storyId}\n`);
    }
  } catch (e) {
    errors.push({ story: storyId, issues: [{ type: "error", message: e.message }] });
    process.stdout.write(`\n❌ ${storyId} — ${e.message}\n`);
  }
}

ws.close();

// ── Summary ──────────────────────────────────────────────────────────────────

console.log(`\n${"─".repeat(72)}`);
console.log(`RESULTS: ${checked} stories checked`);
console.log(`  ✅ ${checked - errors.length - warnings.length} passed`);
if (warnings.length) console.log(`  ⚠️  ${warnings.length} warnings (blank content)`);
if (errors.length)   console.log(`  ❌ ${errors.length} errors`);

if (errors.length > 0) {
  console.log("\n── ERRORS ──");
  errors.forEach(({ story, issues }) => {
    console.log(`\n${story}`);
    issues.forEach(i => console.log(`  ${i.message}`));
  });
  process.exit(1);
}

if (warnings.length > 0) {
  console.log("\n── WARNINGS (may need review) ──");
  warnings.forEach(({ story, issues }) => {
    console.log(`  ${story}: ${issues.map(i=>i.message).join("; ")}`);
  });
}

console.log("\n✓ All stories passed");
process.exit(0);
